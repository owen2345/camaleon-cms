# frozen_string_literal: true

module CamaleonCms
  # Keeps a reload of the routes apart from the requests that run at the same time.
  #
  # PluginRoutes.reload clears the route set of the app and draws it again. A request that runs during
  # the draw finds no route helpers, and it raises a NameError or an ActionController::UrlGenerationError.
  #
  # Each request holds a share of the lock until the app returns its response. A reload takes the lock
  # exclusively: it waits until the other requests are done, and new requests wait until the draw is
  # done. A request that reloads the routes gives up its share while it waits, so two such requests do
  # not wait for each other.
  #
  # A reload can run in a transaction, and a request can wait for a row that the transaction locks. So
  # the reload waits for the requests for WAIT_TIMEOUT seconds at most. Then it draws the routes while
  # they run, as Camaleon did before this lock, and it logs a warning.
  class RouteReloadLock
    WAIT_TIMEOUT = 10

    # The lock that the requests share and that a reload takes exclusively.
    class Lock
      def initialize
        @monitor = Monitor.new
        @changed = @monitor.new_cond
        @shares = Hash.new(0)
        @owner = nil
        @depth = 0
        @waiting = 0
        @yielded = nil
      end

      def sharing
        @monitor.synchronize do
          @changed.wait_while { blocked_for_share? }
          @shares[Thread.current] += 1
        end
        begin
          yield
        ensure
          stop_sharing
        end
      end

      def exclusive(timeout)
        start_exclusive(timeout)
        begin
          yield
        ensure
          stop_exclusive
        end
      end

      private

      # A new request waits while a reload runs or waits. A thread that holds a share or the lock goes on.
      def blocked_for_share?
        return false if @shares.key?(Thread.current) || @owner.equal?(Thread.current)

        !@owner.nil? || @waiting > 0
      end

      def stop_sharing
        @monitor.synchronize do
          @shares[Thread.current] -= 1
          @shares.delete(Thread.current) unless @shares[Thread.current] > 0
          @changed.broadcast
        end
      end

      def start_exclusive(timeout)
        @monitor.synchronize do
          next @depth += 1 if @owner.equal?(Thread.current)

          yielded = @shares.delete(Thread.current)
          @waiting += 1
          begin
            wait_for_turn(monotonic_now + timeout)
            @owner = Thread.current
            @depth = 1
            @yielded = yielded
          ensure
            @waiting -= 1
            # A thread that stops while it waits gets its share back.
            @shares[Thread.current] += yielded if yielded && !@owner.equal?(Thread.current)
            @changed.broadcast
          end
        end
      end

      # Waits until no other reload runs, and until no request runs or the deadline is past.
      def wait_for_turn(deadline)
        loop do
          late = monotonic_now >= deadline
          if @owner.nil? && (@shares.empty? || late)
            log_late_reload unless @shares.empty?
            return
          end

          @changed.wait(late ? nil : deadline - monotonic_now)
        end
      end

      def stop_exclusive
        @monitor.synchronize do
          @depth -= 1
          next if @depth > 0

          @owner = nil
          @shares[Thread.current] += @yielded if @yielded
          @yielded = nil
          @changed.broadcast
        end
      end

      def log_late_reload
        Rails.logger&.warn("Camaleon CMS: the routes reload while #{@shares.size} requests still run")
      end

      def monotonic_now
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end

    LOCK = Lock.new

    # Runs the block when no other request runs, or after WAIT_TIMEOUT seconds.
    def self.exclusive(&)
      LOCK.exclusive(WAIT_TIMEOUT, &)
    end

    def initialize(app)
      @app = app
    end

    # The share ends when the app returns. The body of a streamed response can still use a route
    # helper after that, and a reload does not wait for it (intended): a slow client must not stop
    # each reload and each new request.
    def call(env)
      LOCK.sharing { @app.call(env) }
    end
  end
end
