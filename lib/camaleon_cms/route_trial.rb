# frozen_string_literal: true

require_relative 'route_data'
require_relative 'route_draw_error'

module CamaleonCms
  # The trial draw of the routes. PluginRoutes extends this module.
  #
  # Rails clears the route set of the app before it loads the route files. A route file that raises an
  # error then leaves the app with no routes. A trial loads the route files of Camaleon into an empty
  # route set first. It reads the data of the routes into a RouteData of its own, so it changes
  # nothing that a request reads.
  module RouteTrial
    # The Thread.current key for the draw that runs on the thread.
    DRAW_KEY = :cama_route_draw
    private_constant :DRAW_KEY

    # A draw of this thread: its data, and its route set. The route set is nil for a draw of the app routes.
    Draw = Struct.new(:data, :route_set)
    private_constant :Draw

    # The route set that the route files of Camaleon draw into: the route set of the trial of this
    # thread, or the route set of the app.
    def route_set
      Thread.current[DRAW_KEY]&.route_set || Rails.application.routes
    end

    # Draws the routes on trial. It raises CamaleonCms::RouteDrawError when a route file raises an
    # error, and it changes no route of the app and no cached data.
    def check_routes
      trial_draw
      nil
    end

    # Whether a read on this thread must stay with the thread: a trial draw runs, or a transaction is
    # open. Such a read can give data that is not committed.
    def private_reads?
      drawing_on_trial? || !open_transaction.nil?
    end

    private

    # The route files of Camaleon. The route file of the host app, of a plugin gem or of another engine
    # is not here: such a file can mount an engine, and a mount changes the route set of that engine.
    def route_files
      dir = CamaleonCms::Engine.root.join('config')
      [dir.join('routes.rb'), dir.join('routes', 'admin.rb'), dir.join('routes', 'frontend.rb')].map(&:to_s)
    end

    # Loads the route files into an empty route set, and returns the data that they read.
    def trial_draw
      data = CamaleonCms::RouteData.new
      route_set = ActionDispatch::Routing::RouteSet.new
      # Each route file calls draw, and a draw clears the route set unless this is set.
      route_set.disable_clear_and_finalize = true
      with_draw(data, route_set) { route_files.each { |file| Kernel.load(file) } }
      data
    rescue StandardError, ScriptError => e
      raise CamaleonCms::RouteDrawError.new(e, in_transaction: !open_transaction.nil?)
    end

    # Runs the block as a draw of this thread: a trial with its route set, or the draw of the app routes.
    def with_draw(data, route_set = nil)
      previous = Thread.current[DRAW_KEY]
      Thread.current[DRAW_KEY] = Draw.new(data, route_set)
      yield
    ensure
      Thread.current[DRAW_KEY] = previous
    end

    # The data of the trial that runs on this thread, if any.
    def trial_data
      draw = Thread.current[DRAW_KEY]
      draw.data if draw&.route_set
    end

    def drawing_on_trial?
      !trial_data.nil?
    end

    # Whether a draw runs on this thread: a trial, or the draw of the app routes.
    def drawing?
      !Thread.current[DRAW_KEY].nil?
    end

    # The sites with the data that a draw reads from them (PluginRoutes.get_sites).
    def stored_sites
      CamaleonCms::Site.includes(:metas, :post_types).order(id: :asc).to_a
    end

    # The text of the route files that the draw of this thread read, if a draw runs. The draw of the
    # app routes reads the text that its trial read.
    def route_sources
      Thread.current[DRAW_KEY]&.data&.sources
    end

    # The transaction of this thread that a rollback can undo, or nil. Other transactions can join
    # such a transaction. The transaction that the test fixtures open is not one.
    def open_transaction
      transaction = route_connection&.current_transaction
      transaction if transaction&.joinable?
    end

    # The database connection that this thread uses now, if any. PluginRoutes reads its settings while
    # the app boots, before Active Record has a connection.
    def route_connection
      ActiveRecord::Base.connection_pool.active_connection? if defined?(ActiveRecord::Base)
    rescue ActiveRecord::ActiveRecordError
      nil
    end
  end
end
