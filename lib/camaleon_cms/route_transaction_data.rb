# frozen_string_literal: true

require_relative 'route_data'

module CamaleonCms
  # The data of PluginRoutes that belongs to a transaction. PluginRoutes extends this module.
  #
  # PluginRoutes keeps the site list and the values of cache_variable for all threads. A read while a
  # transaction is open can give data that is not committed. So such a read fills a RouteData of the
  # thread, and only that thread uses it until the transaction is over. Then the settle step runs:
  #
  # - After the commit, it clears the data of all threads when a reload or a reload request made the
  #   data of the thread. It also does the reload that reload_after_commit asked for.
  # - After a rollback, it draws the routes again when a draw of the app routes used that data.
  #
  # The state object of the transaction says when it is over, as in CamaleonCms::Metas. Rails gives no
  # callback for that moment before version 7.2.
  module RouteTransactionData
    # The Thread.current key for the data of the open transaction of the thread.
    TRANSACTION_KEY = :cama_route_transaction
    # The Thread.current key that is set while the thread runs the settle step.
    SETTLE_KEY = :cama_route_settle
    private_constant :TRANSACTION_KEY, :SETTLE_KEY

    # The data of one transaction, and what PluginRoutes must do when that transaction is over.
    class Entry
      attr_reader :data
      # cleared: a reload or a reload request made the data, so the data of all threads is old after
      # the commit. drew: a draw of the app routes used the data. reload_due: reload_after_commit
      # asked for a reload. settled: the settle step took the entry.
      attr_accessor :cleared, :drew, :reload_due, :settled

      def initialize(data, transaction, connection)
        @data = data
        @state = transaction.state
        @connection = connection
        @thread = Thread.current
      end

      # :open, :committed or :rolled_back. The state of a savepoint says committed? when the savepoint
      # is released, and a transaction around it can still roll back. That rollback marks the state as
      # rolled back. So a state that is committed, and not fully committed, counts only when its
      # connection has no open transaction.
      #
      # A commit that loses the connection leaves the state invalidated (Rails 7.1 and later). The
      # database can hold the change or not, so that state counts as rolled back. The thread then
      # drops the data of the transaction, and a draw that used the data runs again.
      def outcome
        return :rolled_back if @state.rolledback? || @state.try(:invalidated?)
        if @state.fully_committed? || (@state.committed? && !@connection.current_transaction.joinable?)
          return :committed
        end

        @thread.alive? ? :open : :rolled_back
      end

      def open?
        !settled && outcome == :open
      end
    end

    # Asks for a reload of the routes after the commit of the transaction that is open on this thread.
    # The cached data of the thread is clear at once, so a later read in the transaction comes from the
    # database. A rollback drops the request. With no open transaction, it calls request_reload now.
    #
    # The reload runs right after the commit when the transaction saved a site or a post type. Else it
    # runs at the next call of PluginRoutes.
    def reload_after_commit
      settle_route_data
      entry = new_transaction_entry
      return request_reload unless entry

      entry.reload_due = true
      nil
    end

    # Does what is left for each transaction that is over: of this thread, and of each other thread.
    # A site and a post type call it after their commit and after their rollback. With quiet, it logs
    # the error of the reload that reload_after_commit asked for, and does not raise it.
    def settle_route_data(quiet: false)
      return unless settle_now?

      Thread.current[SETTLE_KEY] = true
      begin
        committed, rolled_back = finished_entries.partition { |entry| entry.outcome == :committed }
        clear_shared_route_data if committed.any?(&:cleared)
        redrawn = rolled_back.any?(&:drew) && reload_quietly
        reload_for_commit(quiet) if committed.any?(&:reload_due) && !redrawn
      ensure
        Thread.current[SETTLE_KEY] = false
      end
      nil
    end

    private

    # The values of cache_variable that a read on this thread uses.
    def cache
      private_route_data&.cache || (@cache ||= {})
    end

    # The values of cache_variable that a write on this thread fills.
    def cache_to_fill
      (private_route_data || transaction_route_data)&.cache || (@cache ||= {})
    end

    # Loads the site list after a miss: into the data of the open transaction, or for all threads.
    def fill_sites
      data = transaction_route_data
      data ? (data.sites ||= stored_sites) : (@all_sites = stored_sites)
    end

    # The data that only this thread uses: of the trial that runs, or of its open transaction.
    def private_route_data
      trial = trial_data
      return trial if trial

      entry = Thread.current[TRANSACTION_KEY]
      entry.data if entry&.open?
    end

    # The data of the open transaction of this thread, for a read that the shared data cannot answer.
    # The first such read makes the data, as a copy of the shared data.
    def transaction_route_data
      entry = Thread.current[TRANSACTION_KEY]
      return entry.data if entry&.open?

      transaction = open_transaction
      return unless transaction

      data = CamaleonCms::RouteData.new
      data.sites = @all_sites
      data.cache.merge!(@cache) if @cache
      (Thread.current[TRANSACTION_KEY] = Entry.new(data, transaction, route_connection)).data
    end

    # Gives this thread new data for its open transaction: empty, or the data of a trial. The list of
    # all threads keeps the entry, so another thread can settle it. Returns nil with no open transaction.
    def new_transaction_entry(data = CamaleonCms::RouteData.new)
      transaction = open_transaction
      return unless transaction

      entry = Entry.new(data, transaction, route_connection)
      entry.cleared = true
      reload_monitor.synchronize { (@unsettled ||= []) << entry }
      Thread.current[TRANSACTION_KEY] = entry
    end

    # Makes the data of a trial the cached data: of this thread when a transaction is open, else of
    # all threads.
    def use_route_data(data)
      entry = new_transaction_entry(data)
      return entry.drew = true if entry

      @all_sites = data.sites
      @cache = data.cache
      CamaleonCms::Site.forget_main_site
    end

    # Clears the cached data: of this thread when a transaction is open, else of all threads.
    def clear_caches
      clear_shared_route_data unless new_transaction_entry
    end

    def clear_shared_route_data
      reload_monitor.synchronize do
        @all_sites = nil
        @cache&.clear
      end
      CamaleonCms::Site.forget_main_site
    end

    # The settle step does not run in itself, in a draw, or while the thread holds the monitor of the
    # reload: a reload there can wait for the lock of the requests in the wrong order.
    def settle_now?
      return false if Thread.current[SETTLE_KEY] || drawing? || reload_monitor.mon_owned?

      entry = Thread.current[TRANSACTION_KEY]
      @unsettled.present? || (!entry.nil? && !entry.open?)
    end

    # Takes each entry whose transaction is over: the entry of this thread, and the entries of the list.
    def finished_entries
      reload_monitor.synchronize do
        own = Thread.current[TRANSACTION_KEY]
        own = nil if own&.open?
        Thread.current[TRANSACTION_KEY] = nil if own
        finished = (@unsettled || []).reject(&:open?)
        @unsettled -= finished if @unsettled
        finished |= [own] if own
        finished.reject(&:settled).each { |entry| entry.settled = true }
      end
    end

    # A reload after a rollback does not raise: its error can hide the error that caused the rollback.
    def reload_quietly
      reload
      true
    rescue StandardError, ScriptError => e
      log_reload_error(e)
      false
    end

    # The reload that reload_after_commit asked for.
    def reload_for_commit(quiet)
      request_reload
    rescue StandardError, ScriptError => e
      raise unless quiet

      log_reload_error(e)
    end

    def log_reload_error(error)
      Rails.logger&.error("Camaleon CMS: the routes were not drawn again (#{error.class}: #{error.message})")
    end
  end
end
