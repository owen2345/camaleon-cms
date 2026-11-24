# frozen_string_literal: true

# PluginRoutes.reload clears the route set of the app and draws it again. A request that runs during the
# draw finds no route helpers. These examples call the middleware directly, with a small Rack app after
# it, and run each request and each reload in a thread of its own.
RSpec.describe CamaleonCms::RouteReloadLock do
  # The longest time that an example waits for a thread that must finish.
  let(:finish_time) { 5 }
  # The time that an example gives a thread that must not finish, because it waits for the lock.
  let(:block_time) { 0.3 }
  let(:draws) { Queue.new }
  let(:threads) { [] }

  before do
    allow(Rails.application).to receive(:reload_routes!) { draws << :drawn }
    allow(PluginRoutes).to receive(:after_reload_callbacks).and_return([])
  end

  # A thread of a failed example can still wait for the lock. It must not block the next example.
  after { threads.each(&:kill).each(&:join) }

  def spawn(&)
    Thread.new(&).tap { |thread| threads << thread }
  end

  # Returns a middleware whose app runs the block, and a queue that gets an item when the app starts.
  def middleware_for(&app_body)
    started = Queue.new
    app = lambda do |_env|
      started << :started
      app_body&.call
      [200, {}, ['ok']]
    end
    [described_class.new(app), started]
  end

  def request_thread(middleware)
    spawn { middleware.call(Rack::MockRequest.env_for('/')) }
  end

  it 'waits until a request that runs is done before it draws the routes' do
    release = Queue.new
    middleware, started = middleware_for { release.pop }
    request = request_thread(middleware)
    started.pop

    reload = spawn { PluginRoutes.reload }
    expect(reload.join(block_time)).to be_nil
    expect(draws).to be_empty

    release << :go
    expect(request.join(finish_time)).to be(request)
    expect(reload.join(finish_time)).to be(reload)
    expect(draws.size).to eq(1)
  end

  it 'holds a new request until the draw is done' do
    release = Queue.new
    drawing = Queue.new
    allow(Rails.application).to receive(:reload_routes!) do
      drawing << :started
      release.pop
      draws << :drawn
    end
    reload = spawn { PluginRoutes.reload }
    # The trial of the reload can sleep before the draw, so the example waits for the draw itself.
    Timeout.timeout(finish_time) { drawing.pop }

    middleware, started = middleware_for
    request = request_thread(middleware)
    expect(request.join(block_time)).to be_nil
    expect(started).to be_empty

    release << :go
    expect(reload.join(finish_time)).to be(reload)
    expect(request.join(finish_time)).to be(request)
    expect(started.size).to eq(1)
  end

  it 'draws the routes for a request that reloads them' do
    middleware, = middleware_for { PluginRoutes.reload }

    expect(request_thread(middleware).join(finish_time)).not_to be_nil
    expect(draws.size).to eq(1)
  end

  it 'draws the routes for two requests that reload them at the same time' do
    both_started = Queue.new
    go = Queue.new
    middleware, = middleware_for do
      both_started << :started
      go.pop
      PluginRoutes.reload
    end
    requests = Array.new(2) { request_thread(middleware) }
    2.times { both_started.pop }
    2.times { go << :go }

    expect(requests.map { |request| request.join(finish_time) }).to all(be_a(Thread))
    expect(draws.size).to eq(2)
  end

  # A request can wait for a row that the transaction of the reload locks. The reload must not wait
  # for it forever.
  it 'draws the routes after the wait time while a request still runs, and logs a warning' do
    stub_const("#{described_class}::WAIT_TIMEOUT", block_time)
    expect(Rails.logger).to receive(:warn).with(/the routes reload while 1 requests still run/)
    release = Queue.new
    middleware, started = middleware_for { release.pop }
    request_thread(middleware)
    started.pop

    expect(spawn { PluginRoutes.reload }.join(finish_time)).not_to be_nil
    expect(draws.size).to eq(1)
    release << :go
  end

  # A theme switch takes the lock with wait_for_holder. It draws no route when it starts, so its
  # warning does not name a reload.
  it 'logs that a theme switch starts, when a block that waits for the lock holder starts late' do
    stub_const("#{described_class}::WAIT_TIMEOUT", block_time)
    expect(Rails.logger).to receive(:warn).with(/a theme switch starts while 1 requests still run/)
    release = Queue.new
    middleware, started = middleware_for { release.pop }
    request_thread(middleware)
    started.pop
    ran = Queue.new

    switch = spawn { described_class.exclusive(wait_for_holder: true) { ran << :ran } }
    expect(switch.join(finish_time)).to be(switch)
    expect(ran.size).to eq(1)
    release << :go
  end

  # The lock read the clock two times: for the check of the deadline, and then for the wait time. A
  # deadline that passed between the two reads gave a negative wait time, which raises ArgumentError.
  it 'draws the routes when the deadline passes between the check of the time and the wait' do
    stub_const("#{described_class}::WAIT_TIMEOUT", block_time)
    allow(Rails.logger).to receive(:warn)
    allow(described_class::LOCK).to receive(:monotonic_now).and_return(0, block_time - 0.01, block_time + 0.01)
    release = Queue.new
    middleware, started = middleware_for { release.pop }
    request_thread(middleware)
    started.pop

    expect(spawn { PluginRoutes.reload }.join(finish_time)).not_to be_nil
    expect(draws.size).to eq(1)
    release << :go
  end

  # A theme switch holds the lock for its whole time. A reload of another thread can hold a row that the
  # switch waits for, so that reload must not wait for the switch forever.
  describe 'while another thread holds the lock' do
    let(:release) { Queue.new }
    let(:holding) { Queue.new }
    let(:holder) do
      spawn do
        described_class.exclusive do
          holding << :holding
          release.pop
        end
      end
    end

    before do
      stub_const("#{described_class}::WAIT_TIMEOUT", block_time)
      allow(Rails.logger).to receive(:warn)
      holder
      holding.pop
    end

    it 'draws the routes of a reload after the wait time, and logs a warning' do
      expect(Rails.logger).to receive(:warn).with(/the routes reload while another thread holds the lock/)

      expect(spawn { PluginRoutes.reload }.join(finish_time)).not_to be_nil
      expect(draws.size).to eq(1)
      release << :go
      expect(holder.join(finish_time)).to be(holder)
    end

    it 'leaves the lock with the thread that holds it, after a reload with no lock' do
      expect(spawn { PluginRoutes.reload }.join(finish_time)).not_to be_nil
      middleware, started = middleware_for
      request = request_thread(middleware)
      expect(request.join(block_time)).to be_nil
      expect(started).to be_empty

      release << :go
      expect(request.join(finish_time)).to be(request)
      expect(started.size).to eq(1)
    end

    # A theme switch must not run with no lock, so it waits for the thread that holds the lock.
    context 'with a block that waits for that thread' do
      let(:ran) { Queue.new }

      it 'runs the block with the lock after that thread is done' do
        stub_const("#{described_class}::HOLDER_WAIT_TIMEOUT", finish_time)
        waiter = spawn do
          described_class.exclusive(wait_for_holder: true) do
            ran << :ran
            release.pop
          end
        end
        expect(waiter.join(block_time * 2)).to be_nil
        expect(ran).to be_empty

        release << :go
        Timeout.timeout(finish_time) { ran.pop }
        middleware, started = middleware_for
        request = request_thread(middleware)
        expect(request.join(block_time)).to be_nil
        expect(started).to be_empty
        release << :go
        expect(request.join(finish_time)).to be(request)
      end

      it 'raises an error after its wait time, and does not run the block' do
        stub_const("#{described_class}::HOLDER_WAIT_TIMEOUT", block_time * 2)
        waiter = spawn do
          described_class.exclusive(wait_for_holder: true) { ran << :ran }
        rescue described_class::WaitTimeout => e
          e
        end

        expect(waiter.join(finish_time)).to be(waiter)
        expect(waiter.value).to be_a(described_class::WaitTimeout)
        expect(ran).to be_empty
        release << :go
      end
    end
  end

  # A request gives up its share while it waits for the lock. When the wait ends with no lock, the
  # request must get its share back. Otherwise a later reload does not wait for that request.
  describe 'a request that asks for the lock while another thread holds it' do
    let(:release) { Queue.new }
    let(:finish) { Queue.new }
    let(:answers) { Queue.new }

    before do
      stub_const("#{described_class}::WAIT_TIMEOUT", block_time)
      stub_const("#{described_class}::HOLDER_WAIT_TIMEOUT", block_time)
      allow(Rails.logger).to receive(:warn)
    end

    # Starts a request, and then a thread that takes the lock after its wait time, while the request
    # runs. The request then asks for the lock, notes how its wait ends, and runs until the example
    # ends it. Returns the request and the thread that holds the lock.
    def request_and_holder(wait_for_holder:)
      ask = Queue.new
      middleware, started = middleware_for do
        ask.pop
        begin
          described_class.exclusive(wait_for_holder: wait_for_holder) { answers << :no_lock }
        rescue described_class::WaitTimeout
          answers << :wait_timeout
        end
        finish.pop
      end
      request = request_thread(middleware)
      started.pop
      holding = Queue.new
      holder = spawn do
        described_class.exclusive do
          holding << :holding
          release.pop
        end
      end
      Timeout.timeout(finish_time) { holding.pop }
      ask << :go
      [request, holder]
    end

    {
      'with WaitTimeout' => [true, :wait_timeout],
      'with no lock' => [false, :no_lock]
    }.each do |ending, (wait_for_holder, answer)|
      it "makes a later reload wait for that request, after a wait that ends #{ending}" do
        request, holder = request_and_holder(wait_for_holder: wait_for_holder)
        expect(Timeout.timeout(finish_time) { answers.pop }).to eq(answer)
        release << :go
        expect(holder.join(finish_time)).to be(holder)
        stub_const("#{described_class}::WAIT_TIMEOUT", finish_time)

        reload = spawn { PluginRoutes.reload }
        expect(reload.join(block_time)).to be_nil
        expect(draws).to be_empty

        finish << :go
        expect(request.join(finish_time)).to be(request)
        expect(reload.join(finish_time)).to be(reload)
        expect(draws.size).to eq(1)
      end
    end
  end

  # The lock has a wait time for the requests, and a wait time for the thread that holds the lock. A
  # wait for the one must not take time from the other.
  describe 'the wait for the requests and the wait for the thread that holds the lock' do
    let(:wait_time) { 1 }
    let(:take) { Queue.new }
    let(:holding) { Queue.new }
    let(:release) { Queue.new }
    let(:finish) { Queue.new }
    let(:ran) { Queue.new }

    before do
      stub_const("#{described_class}::WAIT_TIMEOUT", wait_time)
      stub_const("#{described_class}::HOLDER_WAIT_TIMEOUT", finish_time * 2)
      allow(Rails.logger).to receive(:warn)
    end

    # Starts a request that takes the lock when the example says so. The request holds the lock until
    # the example releases it, and then it runs until the example ends it.
    def request_that_takes_the_lock
      middleware, started = middleware_for do
        take.pop
        described_class.exclusive do
          holding << :holding
          release.pop
        end
        finish.pop
      end
      request_thread(middleware).tap { started.pop }
    end

    # The example moves the clock of the lock forward, so the reload spends its wait for the request
    # with no sleep. After a sleep, a short stall of the main thread let the reload take the lock first.
    it 'gives a reload its whole wait for the thread that holds the lock, after a wait for a request' do
      ahead = 0
      reads = Queue.new
      allow(described_class::LOCK).to receive(:monotonic_now).and_wrap_original do |clock|
        (clock.call + ahead).tap { reads << :read }
      end
      request = request_that_takes_the_lock
      reload = spawn { described_class.exclusive { ran << :ran } }
      # The lock reads the clock two times before the reload waits.
      2.times { Timeout.timeout(finish_time) { reads.pop } }
      ahead = wait_time * 0.75
      take << :go
      Timeout.timeout(finish_time) { holding.pop }

      # With one wait time for both waits, the reload ran with no lock a quarter of the wait time
      # after the lock was taken. The reload now waits for the whole wait time from then on.
      expect(reload.join(wait_time * 0.4)).to be_nil
      expect(ran).to be_empty

      release << :go
      finish << :go
      expect(request.join(finish_time)).to be(request)
      expect(reload.join(finish_time)).to be(reload)
      expect(ran.size).to eq(1)
    end

    it 'gives a theme switch its whole wait for the requests, after a wait for the thread that holds the lock' do
      expect(Rails.logger).not_to receive(:warn)
      request = request_that_takes_the_lock
      take << :go
      Timeout.timeout(finish_time) { holding.pop }
      switch = spawn { described_class.exclusive(wait_for_holder: true) { ran << :ran } }
      sleep(wait_time * 1.25)

      # The request of the holder has its share back, and it still runs. With one wait time for both
      # waits, the switch started at once.
      release << :go
      expect(switch.join(wait_time * 0.25)).to be_nil
      expect(ran).to be_empty

      finish << :go
      expect(request.join(finish_time)).to be(request)
      expect(switch.join(finish_time)).to be(switch)
      expect(ran.size).to eq(1)
    end
  end

  # A fiber server runs each request in a fiber, and those fibers can share one thread. Such an app
  # sets config.active_support.isolation_level to :fiber. The lock then counts each fiber, not each
  # thread. The examples set that level only for the thread that they start.
  describe 'when the app isolates its state by fiber' do
    let(:ran) { Queue.new }

    before do
      stub_const("#{described_class}::WAIT_TIMEOUT", block_time)
      stub_const("#{described_class}::HOLDER_WAIT_TIMEOUT", block_time)
      allow(Rails.logger).to receive(:warn)
      allow(ActiveSupport::IsolatedExecutionState).to receive(:isolation_level).and_wrap_original do |level|
        Thread.current.thread_variable_get(:cama_fiber_isolation) ? :fiber : level.call
      end
    end

    def fiber_isolated_thread
      spawn do
        Thread.current.thread_variable_set(:cama_fiber_isolation, true)
        yield
      end
    end

    it 'makes a theme switch wait for a switch in another fiber of its thread' do
      thread = fiber_isolated_thread do
        described_class.exclusive do
          Fiber.new do
            described_class.exclusive(wait_for_holder: true) { ran << :ran }
          rescue described_class::WaitTimeout => e
            e
          end.resume
        end
      end

      expect(thread.join(finish_time)).to be(thread)
      expect(thread.value).to be_a(described_class::WaitTimeout)
      expect(ran).to be_empty
    end

    it 'makes a reload wait for a request in another fiber of its thread' do
      expect(Rails.logger).to receive(:warn).with(/the routes reload while 1 requests still run/)
      middleware, = middleware_for { Fiber.new { described_class.exclusive { ran << :ran } }.resume }

      thread = fiber_isolated_thread { middleware.call(Rack::MockRequest.env_for('/')) }

      expect(thread.join(finish_time)).to be(thread)
      expect(ran.size).to eq(1)
    end

    it 'counts each thread when the app isolates its state by thread' do
      expect(Rails.logger).not_to receive(:warn)
      middleware, = middleware_for { Fiber.new { described_class.exclusive { ran << :ran } }.resume }

      thread = spawn { middleware.call(Rack::MockRequest.env_for('/')) }

      expect(thread.join(finish_time)).to be(thread)
      expect(ran.size).to eq(1)
    end
  end

  it 'lets the next request run after a request that raised' do
    failing, = middleware_for { raise 'broken' }
    expect { failing.call(Rack::MockRequest.env_for('/')) }.to raise_error('broken')

    expect(spawn { PluginRoutes.reload }.join(finish_time)).not_to be_nil
  end

  it 'is in the middleware stack of the app' do
    expect(Rails.application.middleware.middlewares).to include(described_class)
  end
end
