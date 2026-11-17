# frozen_string_literal: true

module CamaleonCms
  # The reload of the routes. PluginRoutes extends this module.
  #
  # `reload` clears the caches of PluginRoutes and draws the routes now. Code that makes more than one
  # change runs in a `reload_once` block and calls `request_reload` for each change. A draw that adds
  # no route then waits for the end of the block, and the block draws the routes one time.
  module RouteReload
    # The Thread.current key for the state of a reload_once block.
    BLOCK_KEY = :cama_route_reload_block
    private_constant :BLOCK_KEY

    # Reloads the routes now. The reload waits until the other requests are done, and new requests
    # wait until it is done (CamaleonCms::RouteReloadLock).
    def reload
      CamaleonCms::RouteReloadLock.exclusive do
        reload_monitor.synchronize do
          clear_caches
          # A draw that raises an error leaves no record, so the next call in a block draws at once.
          @drawn_route_inputs = nil
          Rails.application.reload_routes!
          @drawn_route_inputs = route_inputs
          after_reload_callbacks.uniq.each(&:call)
        end
      end
      # This draw is also the draw that a reload_once block of this thread waited for.
      block = Thread.current[BLOCK_KEY]
      block[:draw_waits] = false if block
      nil
    end

    # Runs the block. At its end, it draws the routes one time when a request_reload call in the
    # block left a draw to it and the block drew no routes after that call. It draws them also when
    # the block raises an error. A block in a block leaves the draw to the outer block.
    def reload_once
      return yield if Thread.current[BLOCK_KEY]

      block = Thread.current[BLOCK_KEY] = { draw_waits: false }
      begin
        yield
      ensure
        Thread.current[BLOCK_KEY] = nil
        reload if block[:draw_waits]
      end
    end

    # Reloads the routes. In a reload_once block, the draw waits for the end of the block when it
    # adds no route. So no plugin hook and no model callback in the block misses a route helper. The
    # caches are clear at once in each case.
    def request_reload
      block = Thread.current[BLOCK_KEY]
      return reload if block.nil? || adds_routes?

      block[:draw_waits] = true
      nil
    end

    private

    def clear_caches
      @all_sites = nil
      cache.clear
    end

    # The data from the database that a draw of the routes reads.
    def route_inputs
      {
        locales: all_locales.split('|'),
        post_types: get_sites.flat_map { |site| site.post_types.map { |post_type| [post_type.id, post_type.slug] } },
        plugins: all_enabled_plugins.pluck('key'),
        themes: all_enabled_themes.pluck('key')
      }
    end

    # Whether a draw now gives a route that the last reload did not give: a new post type or slug, a
    # new plugin or theme, or a new language. A part that is gone adds no route, so its draw waits.
    # It reads the data again, so the caches are fresh.
    def adds_routes?
      reload_monitor.synchronize do
        clear_caches
        drawn = @drawn_route_inputs
        drawn.nil? || route_inputs.any? { |part, present| (present - drawn[part]).any? }
      end
    end
  end
end
