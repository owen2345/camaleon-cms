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
    allow(Rails.application).to receive(:reload_routes!) do
      release.pop
      draws << :drawn
    end
    reload = spawn { PluginRoutes.reload }
    Timeout.timeout(finish_time) { Thread.pass until reload.status == 'sleep' }

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

  it 'lets the next request run after a request that raised' do
    failing, = middleware_for { raise 'broken' }
    expect { failing.call(Rack::MockRequest.env_for('/')) }.to raise_error('broken')

    expect(spawn { PluginRoutes.reload }.join(finish_time)).not_to be_nil
  end

  it 'is in the middleware stack of the app' do
    expect(Rails.application.middleware.middlewares).to include(described_class)
  end
end
