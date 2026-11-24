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
  #
  # A theme switch holds the lock for its whole time, and it can wait for a row that the transaction of
  # a reload locks. So a reload waits for the thread that holds the lock for WAIT_TIMEOUT seconds at
  # most too. Then it draws the routes with no lock, and it logs a warning.
  #
  # A theme switch must not run with no lock. It waits for the thread that holds the lock for
  # HOLDER_WAIT_TIMEOUT seconds at most, and then it raises WaitTimeout. Only a theme switch takes the
  # lock this way, so the warning for a late start then names a theme switch.
  #
  # The two waits have a time each. The wait for the requests counts only the time with no thread that
  # holds the lock. The wait for that thread counts only the time with one. So a reload waits for
  # 2 x WAIT_TIMEOUT seconds at most, and a theme switch for WAIT_TIMEOUT + HOLDER_WAIT_TIMEOUT seconds.
  #
  # A fiber server runs each request in a fiber, and those fibers can share one thread. Such an app
  # sets config.active_support.isolation_level to :fiber. Each fiber then holds its own share, and one
  # fiber holds the lock: read "fiber" for each "thread" in this file.
  class RouteReloadLock
    WAIT_TIMEOUT = 10
    HOLDER_WAIT_TIMEOUT = 30

    # Another thread held the lock for the whole wait time of a block that must not run with no lock.
    class WaitTimeout < StandardError; end

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
          @shares[current] += 1
        end
        begin
          yield
        ensure
          stop_sharing
        end
      end

      # With a holder_timeout, the block never runs with no lock. The thread waits that time for the
      # thread that holds the lock, and then it raises WaitTimeout.
      def exclusive(timeout, holder_timeout: nil)
        held = start_exclusive(timeout, holder_timeout)
        begin
          yield
        ensure
          stop_exclusive if held
        end
      end

      private

      # A new request waits while a reload runs or waits. A thread that holds a share or the lock goes on.
      def blocked_for_share?
        return false if @shares.key?(current) || @owner.equal?(current)

        !@owner.nil? || @waiting > 0
      end

      def stop_sharing
        @monitor.synchronize do
          @shares[current] -= 1
          @shares.delete(current) unless @shares[current] > 0
          @changed.broadcast
        end
      end

      # Returns whether the thread holds the lock now. It is false when another thread still holds the
      # lock after the wait time. The thread then runs its block with no lock, and a request keeps its share.
      def start_exclusive(timeout, holder_timeout)
        @monitor.synchronize do
          if @owner.equal?(current)
            @depth += 1
            next true
          end

          yielded = @shares.delete(current)
          @waiting += 1
          begin
            next false unless wait_for_turn(timeout, holder_timeout)

            @owner = current
            @depth = 1
            @yielded = yielded
            true
          ensure
            @waiting -= 1
            # A thread that does not get the lock gets its share back.
            @shares[current] += yielded if yielded && !@owner.equal?(current)
            @changed.broadcast
          end
        end
      end

      # Waits until no other thread holds the lock and no request runs, or until a wait time is spent.
      # Returns whether the lock is free: false when another thread still holds it after the wait time
      # for that thread. With a holder_timeout, that wait time is the holder_timeout, and the thread
      # then raises WaitTimeout.
      #
      # The wait for the requests and the wait for the thread that holds the lock have a time each. A
      # turn of the loop takes the time since the last turn from the wait that the last turn saw. It
      # reads the clock one time, so the time of a wait is never negative.
      def wait_for_turn(timeout, holder_timeout)
        left = { false => timeout, true => holder_timeout || timeout }
        last = monotonic_now
        held = !@owner.nil?
        loop do
          now = monotonic_now
          left[held] -= now - last
          last = now
          held = !@owner.nil?
          spent = left[held] <= 0
          return give_up(holder_timeout) if held && spent
          return start_turn(holder_timeout) if !held && (@shares.empty? || spent)

          @changed.wait(left[held])
        end
      end

      # The lock is free. A request can still run when the wait time for the requests is spent.
      def start_turn(holder_timeout)
        log_late_start(holder_timeout) unless @shares.empty?
        true
      end

      # Ends a wait for a thread that still holds the lock: with an error, or with false and a warning.
      def give_up(holder_timeout)
        raise WaitTimeout, 'Camaleon CMS - Another thread still holds the lock of the route reload' if holder_timeout

        log_reload_with_no_lock
        false
      end

      def stop_exclusive
        @monitor.synchronize do
          @depth -= 1
          next if @depth > 0

          @owner = nil
          @shares[current] += @yielded if @yielded
          @yielded = nil
          @changed.broadcast
        end
      end

      # A thread with a holder_timeout is a theme switch, and it draws no route when it starts.
      def log_late_start(holder_timeout)
        work = holder_timeout ? 'a theme switch starts' : 'the routes reload'
        Rails.logger&.warn("Camaleon CMS: #{work} while #{@shares.size} requests still run")
      end

      def log_reload_with_no_lock
        Rails.logger&.warn('Camaleon CMS: the routes reload while another thread holds the lock of the reload')
      end

      # What holds a share or the lock: the thread, or the fiber when the app isolates its state by
      # fiber. Rails has that setting from version 7.0.
      def current
        state = ActiveSupport::IsolatedExecutionState if defined?(ActiveSupport::IsolatedExecutionState)
        state&.isolation_level == :fiber ? Fiber.current : Thread.current
      end

      def monotonic_now
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end

    LOCK = Lock.new

    # Runs the block when no other request runs, or after WAIT_TIMEOUT seconds. With wait_for_holder,
    # the block never runs with no lock: see WaitTimeout.
    def self.exclusive(wait_for_holder: false, &)
      LOCK.exclusive(WAIT_TIMEOUT, holder_timeout: (HOLDER_WAIT_TIMEOUT if wait_for_holder), &)
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
