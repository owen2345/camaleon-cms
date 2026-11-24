# frozen_string_literal: true

# A hook of a theme switch can draw the routes in the transaction of the switch, and that draw waits for the
# requests that run. A request that started during the switch could wait for a lock of that transaction, for
# example the write lock of SQLite. The draw and the request then waited for each other.
# The example calls the middleware of the lock directly, and runs the request in a thread of its own.
RSpec.describe 'The route reload lock of a theme switch' do
  include_context 'with theme hook probes'
  init_site

  # The time that the hook gives a request that must not start, because it waits for the lock.
  let(:block_time) { 0.3 }
  let(:helper_object) do
    Class.new do
      include CamaleonCms::PluginsHelper
      include CamaleonCms::HooksHelper
    end.new
  end
  let(:in_switch) { Queue.new }
  let(:request_started) { Queue.new }
  let(:switch_done) { Queue.new }
  let(:threads) { [] }

  # The on_active handler of the new theme tells the request to start, and waits for it. Then it installs
  # a plugin, which draws the routes.
  def probe_helper
    log = hook_log
    signal = in_switch
    started = request_started
    wait = block_time
    Module.new do
      define_method(:probe_new_on_active) do |_theme|
        signal << :in_switch
        log << (started.pop(timeout: wait) ? :request_in_switch : :no_request_in_switch)
        plugin_install('visibility_post')
      end
    end
  end

  # A request that starts during the switch. Its app ends only after the switch, as a request that waits
  # for a lock of the transaction of the switch does.
  def request_during_the_switch
    app = lambda do |_env|
      request_started << :started
      switch_done.pop
      [200, {}, ['ok']]
    end
    middleware = CamaleonCms::RouteReloadLock.new(app)
    threads << Thread.new do
      in_switch.pop
      middleware.call(Rack::MockRequest.env_for('/'))
    end
  end

  before do
    stub_const('CamaleonCms::RouteReloadLock::WAIT_TIMEOUT', 1)
    probe_theme_hooks(probe_helper, 'default' => {}, 'new' => { 'on_active' => ['probe_new_on_active'] })
    CurrentRequest.site = @site
    allow(Rails.logger).to receive(:warn)
  end

  # A thread of a failed example can still wait for the lock. It must not block the next example.
  after { threads.each(&:kill).each(&:join) }

  it 'holds a request that starts during the switch until the switch is done' do
    expect(Rails.logger).not_to receive(:warn).with(/requests still run/)
    request_during_the_switch

    helper_object.site_install_theme('new')
    switch_done << :go

    expect(hook_log).to eq([:no_request_in_switch])
    expect(threads.first.join(5)).to be(threads.first)
    expect(CamaleonCms::Site.find(@site.id).get_theme_slug).to eq('new')
  end

  # After the wait time of the lock, a reload draws with no lock while another thread holds the lock. A
  # second switch at the same time ran with no lock in the same way.
  describe 'a switch while another thread holds the lock' do
    let(:release) { Queue.new }
    let(:holding) { Queue.new }

    before do
      stub_const('CamaleonCms::RouteReloadLock::WAIT_TIMEOUT', 0.2)
      threads << Thread.new do
        CamaleonCms::RouteReloadLock.exclusive do
          holding << :holding
          release.pop
        end
      end
      holding.pop
    end

    it 'raises an error after its wait time, and keeps the theme' do
      stub_const('CamaleonCms::RouteReloadLock::HOLDER_WAIT_TIMEOUT', 0.5)

      expect { helper_object.site_install_theme('new') }
        .to raise_error(CamaleonCms::RouteReloadLock::WaitTimeout)
      expect(hook_log).to be_empty
      expect(CamaleonCms::Site.find(@site.id).get_theme_slug).to eq('default')
    end

    # The switch runs in a thread of its own, which uses the database connection of the example.
    it 'starts after that thread is done' do
      site = @site
      switch = Thread.new do
        CurrentRequest.site = site
        helper_object.site_install_theme('new')
      ensure
        CurrentRequest.reset
      end
      threads << switch
      # With no lock, the hook ran after the wait time of the lock and logged after its own wait.
      expect(switch.join(0.2 + (block_time * 2))).to be_nil
      expect(hook_log).to be_empty

      release << :go
      expect(switch.join(5)).to be(switch)
      expect(hook_log).to eq([:no_request_in_switch])
      expect(CamaleonCms::Site.find(@site.id).get_theme_slug).to eq('new')
    end
  end
end
