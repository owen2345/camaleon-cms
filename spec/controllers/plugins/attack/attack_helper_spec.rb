# frozen_string_literal: true

# H2 — the attack throttle used to key on cama_get_session_id, so a cookieless / cookie-rotating
# request presented a fresh id every time: the per-key counter never accumulated, the throttle never
# tripped, and its per-request DB insert ran unbounded. It now keys on the client IP.
RSpec.describe Plugins::Attack::AttackHelper, type: :controller do
  let(:site) { CamaleonCms::Site.first }
  let(:client_ip) { '203.0.113.7' }
  let(:ban_key) { "plugins_attack_ban:#{client_ip}" }

  controller(ActionController::Base) do
    # rubocop:disable RSpec/DescribedClass
    include Plugins::Attack::AttackHelper
    # rubocop:enable RSpec/DescribedClass

    def index
      attack_app_before_load
      render(plain: 'ok') unless performed?
    end

    def current_site
      CamaleonCms::Site.first
    end

    # Simulate the cookieless / cookie-rotating attacker: a FRESH session id every request. The fix
    # ignores this entirely (it keys on request.remote_ip), so the IP-keyed assertions below hold.
    # On the unfixed code the per-session-id counter never accumulates, so the ban never trips and
    # the per-request DB insert runs unbounded — which is exactly what the H2 cases here reproduce.
    def cama_get_session_id
      SecureRandom.hex(8)
    end
  end

  before do
    routes.draw { match 'index' => 'anonymous#index', via: %i[get post] }
    ActiveRecord::Base.connection.create_table :plugins_attacks, if_not_exists: true do |t|
      t.string :path
      t.string :browser_key
      t.belongs_to :site
      t.datetime :created_at
    end
    request.remote_addr = client_ip
  end

  after { Rails.cache.delete(ban_key) }

  it 'escapes cached ban messages before rendering them' do
    Rails.cache.write(ban_key, '<script>alert(1)</script>')

    get :index

    expect(response.body).to include('&lt;script&gt;alert(1)&lt;/script&gt;')
    expect(response.body).not_to include('<script>')
  end

  context 'with the throttle configured' do
    before do
      site.set_meta('attack_config', { get: { sec: 60, max: 3 }, post: { sec: 60, max: 3 },
                                       msg: 'request limit exceeded', ban: 5, cleared: Time.zone.now.iso8601 })
    end

    it 'records the client IP as the throttle key, not the session id' do
      get :index

      expect(site.attack.last.browser_key).to eq(client_ip)
    end

    it 'bans the IP once over the limit and then stops inserting rows (bounded write)' do
      # max=3: a few rows accrue until the count trips the limit, then the ban blocks every insert.
      6.times { get :index }
      expect(response.body).to include('request limit exceeded') # the IP is banned now

      rows_after_ban = site.attack.count
      3.times { get :index }

      # Once banned, attack_app_before_load short-circuits and writes nothing more, so the total
      # stays put. On the unfixed code the rotating session id never let the counter accumulate, so
      # it never banned and inserted a row on every request — the unbounded write H2 is about.
      expect(site.attack.count).to eq(rows_after_ban)
      expect(rows_after_ban).to be <= 4 # max(3) + the request that tripped the limit
    end
  end
end
