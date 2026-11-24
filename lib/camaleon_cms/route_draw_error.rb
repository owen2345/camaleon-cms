# frozen_string_literal: true

module CamaleonCms
  # A trial draw of the routes failed, in PluginRoutes.reload or PluginRoutes.check_routes. The message
  # names the error of the route file, and `cause` is that error. The routes of the app and the cached
  # data of PluginRoutes did not change.
  class RouteDrawError < StandardError
    # Whether a transaction was open on the thread at the failure. The error then goes through that
    # transaction, which rolls back. A theme switch gives false for its draw after the savepoint,
    # because the switch stays (site_install_theme).
    attr_reader :in_transaction
    alias in_transaction? in_transaction

    def initialize(error, in_transaction:)
      @in_transaction = in_transaction
      super("#{error.class}: #{error.message.to_s.lines.first.to_s.strip}")
    end
  end
end
