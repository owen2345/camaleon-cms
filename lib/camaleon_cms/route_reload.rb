# frozen_string_literal: true

module CamaleonCms
  # The reload of the routes. PluginRoutes extends this module.
  #
  # `reload` draws the routes on trial (CamaleonCms::RouteTrial), and then draws the routes of the app
  # from the data of that trial. Code that already ran a trial with `trial_routes` gives it to the
  # reload. The comment of `reload` says when the reload still runs a trial of its own. Code that makes
  # more than one change runs in a `reload_once` block and calls `request_reload` for each change. A
  # draw that adds no route then waits for the end of the block, and the block draws the routes one time.
  module RouteReload
    # The Thread.current key for the state of a reload_once block.
    BLOCK_KEY = :cama_route_reload_block
    private_constant :BLOCK_KEY

    # The Thread.current key for the last draw of this thread that read only stored rows. Such a draw
    # uses data of its own reload, with no open transaction. The value is the count of all reloads at
    # the end of that draw (@reloads).
    OWN_DRAW_KEY = :cama_route_reload_own_draw
    private_constant :OWN_DRAW_KEY

    # A trial of the routes, which a later reload can draw from (trial_routes). The state is the state of
    # the transaction that was open at the trial, if any. The outer state is the state of the outermost
    # transaction that a rollback can undo, which is the same transaction or a transaction around it.
    Trial = Struct.new(:data, :reloads, :state, :outer_state)
    private_constant :Trial

    # Reloads the routes now. A trial that fails raises CamaleonCms::RouteDrawError, and the routes and
    # the cached data stay as they were. The draw of the app routes waits until the other requests are
    # done, and new requests wait until it is done (CamaleonCms::RouteReloadLock). The trial does not
    # wait, and no request waits for it.
    #
    # With a trial of trial_routes, the reload draws from the data of that trial, and it runs no trial
    # of its own. When another reload drew the routes after that trial, it runs a trial again. It runs
    # a trial again also when the transaction of that trial rolled back. The data of the trial can
    # then hold rows that the database does not have.
    #
    # A trial reads the rows as its transaction sees them. Another connection can commit a row that
    # the transaction does not see, for example under REPEATABLE READ. So the reload runs a trial again
    # also after the commit of the outermost transaction that was open at the trial (trial_committed?).
    #
    # The other reload can be a reload of this thread, for example of a commit callback. When it is
    # the last draw and it read only stored rows, the reload with the trial draws nothing (drew_after?).
    def reload(trial: nil)
      settle_route_data
      trial = nil if trial_rolled_back?(trial)
      return if trial && drew_after?(trial)

      trial = nil if trial_committed?(trial)
      reloads = trial ? trial.reloads : @reloads
      data = trial ? trial.data : trial_draw
      own_data = trial.nil?
      CamaleonCms::RouteReloadLock.exclusive do
        reload_monitor.synchronize do
          # Another reload drew the routes after the trial, so its data can be newer than this data.
          unless reloads == @reloads
            data = trial_draw
            own_data = true
          end
          @reloads = @reloads.to_i + 1
          draw_app_routes(data)
          Thread.current[OWN_DRAW_KEY] = (@reloads if own_data && open_transaction.nil?)
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
    # adds no route. So no plugin hook and no model callback in the block misses a route helper. In a
    # block, the caches are clear at once. With no block, the reload replaces the cached data, and a
    # trial that fails leaves that data as it was. A draw at once uses the trial, as reload says, and
    # a draw at the end of the block runs a trial of its own.
    def request_reload(trial: nil)
      settle_route_data
      block = Thread.current[BLOCK_KEY]
      # With no trial, a draw at once reads the data again, after adds_routes? read it (intended).
      # Another thread can reload the routes before this draw starts, and its caches lack the changes
      # that this thread did not commit yet.
      return reload(trial: trial) if block.nil? || adds_routes?

      block[:draw_waits] = true
      nil
    end

    # Draws the routes on trial, as check_routes does, and returns the trial for a later reload or
    # request_reload. So code that checks the routes in a savepoint, and then reloads them in the
    # transaction around that savepoint, runs one trial. After the commit of the outermost transaction,
    # the reload reads the database again, as reload says.
    def trial_routes
      reloads = @reloads
      state = open_transaction&.state
      outer_state = outer_transaction_state
      Trial.new(trial_draw, reloads, state, outer_state)
    end

    # The default host that the last reload gave to the routes: the slug of the main site as that
    # reload read it. It is nil with no record of a reload.
    def drawn_default_host
      @drawn_default_host if @drawn_route_inputs
    end

    private

    # Whether the transaction that was open at the trial rolled back. A commit that loses the
    # connection counts as a rollback, as for the data of a transaction (RouteTransactionData).
    def trial_rolled_back?(trial)
      state = trial&.state
      return false unless state

      state.rolledback? || state.try(:invalidated?)
    end

    # Whether the outermost transaction that was open at the trial committed. The database can then hold
    # a newer row than the data of the trial. A transaction that is open now is then a later transaction,
    # and a trial in it can read that row. The state of a savepoint says committed at its release, so
    # the method reads the outer state.
    #
    # While the transaction around a savepoint is open, the reload draws from the data of the trial.
    # Under REPEATABLE READ, a new trial reads the same view. Under READ COMMITTED, a new trial can read
    # a newer row of another connection, and the reload does not read that row (intended).
    def trial_committed?(trial)
      trial&.outer_state&.committed? || false
    end

    # Whether the last draw of the routes is a draw of this thread after the trial, which read only
    # stored rows (OWN_DRAW_KEY). That draw read the stored rows later than the trial did, so the routes
    # need no draw from the data of the trial. A draw in a transaction does not count: a rollback can
    # remove its rows. A draw from an older trial does not count: it can lack rows of this trial.
    def drew_after?(trial)
      reloads = @reloads
      reloads != trial.reloads && Thread.current[OWN_DRAW_KEY] == reloads
    end

    # Makes the data of a trial the cached data, and draws the routes of the app. The route files of
    # Camaleon then read that data and the route file text of the trial. From the database, they
    # read only the main site, for the default host, when its memo is clear.
    def draw_app_routes(data)
      use_route_data(data)
      # A draw that raises an error leaves no record, so the next call in a block draws at once.
      @drawn_route_inputs = nil
      with_draw(data) { Rails.application.reload_routes! }
      @drawn_route_inputs = route_inputs
      @drawn_default_host = default_url_options[:host]
      after_reload_callbacks.uniq.each(&:call)
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
