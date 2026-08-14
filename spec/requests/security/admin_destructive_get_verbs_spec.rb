# frozen_string_literal: true

require 'rails_helper'

include CamaleonCms::PluginsHelper

# Security (audit 2026-08-11 M6, follow-up to #1252): state-changing admin endpoints were plain GET
# routes, so a forged <img>/link could trash or restore posts, flip comment moderation, toggle or
# upgrade plugins, switch an admin's session to another user (impersonate), send mail, or end a
# session -- Rails' CSRF protection exempts GET (and HEAD) entirely. Each endpoint now acts only
# over its proper verb, carried by jquery_ujs data-method links or button_to forms. A GET to the
# old paths no longer matches an admin route (it falls through to the frontend catch-all and
# renders not-found) and, decisively, performs no state change. Logout answers a GET with a
# confirmation page instead -- frontend themes across the ecosystem link that path -- and ends the
# session only on POST.
#
# Follow-up 2 converts the JS-coupled surface the first pass deferred: the nav-menu item delete
# (DELETE; the admin JS sends a token-bearing ajax), the legacy appearances widgets delete routes
# (GET dropped), and media crop (POST-only; `via: :all` admitted every verb, GET and HEAD included).
RSpec.describe 'Security: destructive admin actions are not reachable over GET (M6)', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  let(:admin_user) do
    create(:user_admin, site: current_site, password: 'longenough1', password_confirmation: 'longenough1')
  end
  let(:post_type) { current_site.post_types.find_by(slug: 'post') }

  before { sign_in_as(admin_user, site: current_site) }

  describe 'posts trash and restore' do
    let!(:post_record) { create(:post, post_type: post_type, owner: admin_user) }

    it 'performs no state change over GET' do
      get "/admin/post_type/#{post_type.id}/posts/#{post_record.id}/trash"

      expect(response).not_to have_http_status(:redirect) # the admin action would redirect
      expect(post_record.reload.status).not_to eq('trash')
    end

    it 'trashes and restores over PATCH' do
      patch "/admin/post_type/#{post_type.id}/posts/#{post_record.id}/trash"
      expect(post_record.reload.status).to eq('trash')

      patch "/admin/post_type/#{post_type.id}/posts/#{post_record.id}/restore"
      expect(post_record.reload.status).not_to eq('trash')
    end
  end

  describe 'comment moderation toggle' do
    let!(:post_record) { create(:post, post_type: post_type, owner: admin_user) }
    let!(:comment) do
      post_record.comments.create!(content: 'a comment', author: 'Guest', author_email: 'guest@example.com',
                                   approved: 'pending')
    end

    it 'performs no state change over GET' do
      get "/admin/posts/#{post_record.id}/comments/#{comment.id}/toggle_status", params: { s: 'a' }

      expect(comment.reload.approved).to eq('pending')
    end

    it 'flips the status over PATCH' do
      patch "/admin/posts/#{post_record.id}/comments/#{comment.id}/toggle_status", params: { s: 'a' }

      expect(comment.reload.approved).to eq('approved')
    end
  end

  describe 'plugin toggle and upgrade' do
    before { plugin_install('attack') }

    it 'performs no state change over GET' do
      get '/admin/plugins/toggle', params: { id: 'attack', status: 'true' }

      expect(current_site.plugins.active.pluck(:slug)).to include('attack') # still active
    end

    it 'deactivates a plugin over PATCH' do
      patch '/admin/plugins/toggle', params: { id: 'attack', status: 'true' }

      expect(response).to redirect_to(action: :index)
      expect(current_site.plugins.active.pluck(:slug)).not_to include('attack')
    end

    it 'performs no upgrade over GET' do
      expect(PluginRoutes).not_to receive(:reload) # the upgrade action reloads routes; the no-op must not

      get '/admin/plugins/attack/upgrade'

      expect(response).not_to have_http_status(:redirect) # the admin action redirects; the no-op does not
    end

    it 'upgrades a plugin over POST' do
      allow_any_instance_of(CamaleonCms::Admin::PluginsController)
        .to receive(:plugin_upgrade).and_return(double(title: 'Attack', error: false))
      expect(PluginRoutes).to receive(:reload)

      post '/admin/plugins/attack/upgrade'

      expect(response).to redirect_to(action: :index)
    end
  end

  describe 'user impersonation' do
    let!(:target) { create(:user, site: current_site) }

    # The auth cookie is stored as "<token>&<user_agent>&<ip>"; assert on the token the jar holds
    # (the impersonation suites' auth_token_in_jar idiom) rather than scraping a rendered page.
    def auth_token_in_jar
      cookies[:auth_token].to_s.split('&').first
    end

    it 'performs no session switch over GET' do
      get "/admin/users/#{target.id}/impersonate"

      expect(auth_token_in_jar).to eq(admin_user.auth_token)
      expect(auth_token_in_jar).not_to eq(target.auth_token)
    end

    it 'switches the session over POST' do
      post "/admin/users/#{target.id}/impersonate"

      expect(auth_token_in_jar).to eq(target.auth_token)
      expect(auth_token_in_jar).not_to eq(admin_user.auth_token)
    end
  end

  describe 'test email' do
    it 'sends nothing over GET' do
      expect do
        get '/admin/settings/test_email', params: { email: 'x@example.com' }
      end.not_to(change { ActionMailer::Base.deliveries.count })
    end

    it 'sends over POST' do
      post '/admin/settings/test_email', params: { email: 'x@example.com' }

      expect(response).to have_http_status(:ok).or have_http_status(:bad_gateway)
    end
  end

  describe 'theme load_data (clears and re-imports post types, nav menus, sliders)' do
    # load_data delegates to the export_content plugin's importer, so pin the security-relevant fact
    # at the routing layer (no controller/template/plugin execution): GET must not reach the action,
    # POST must. Reproduces against the old routes, where GET recognized as load_data.
    let(:path) { '/admin/appearances/themes/load_data' }

    it 'does not route a GET to the import action' do
      recognized = Rails.application.routes.recognize_path(path, method: :get)

      expect(recognized).not_to include(action: 'load_data')
    end

    it 'routes a POST to the import action' do
      recognized = Rails.application.routes.recognize_path(path, method: :post)

      expect(recognized).to include(controller: 'camaleon_cms/admin/appearances/themes',
                                    action: 'load_data')
    end
  end

  describe 'nav menu item delete (destroys a menu item)' do
    let(:nav_menu) { current_site.nav_menus.first }
    let!(:menu_item) { nav_menu.append_menu_item(label: 'A link', type: 'external', link: 'http://example.com') }
    let(:path) { "/admin/appearances/nav_menus/#{nav_menu.id}/item_delete/#{menu_item.id}" }

    it 'performs no state change over GET' do
      get path

      expect(current_site.nav_menu_items.where(id: menu_item.id)).to exist
    end

    it 'destroys the item over DELETE' do
      delete path

      expect(response).to have_http_status(:ok)
      expect(current_site.nav_menu_items.where(id: menu_item.id)).not_to exist
    end
  end

  describe 'legacy appearances widgets delete routes' do
    # The widgets/widget_delete matches predate the widgets/{main,sidebar,assign} controllers --
    # their target controller was deleted in 2015 (34159392), so nothing executes (even
    # recognize_path refuses the missing constant, on every verb) -- but the routes still admitted
    # GET for delete-shaped endpoints. Pin the fact where the audit spec enforces it, on the loaded
    # route table: the delete surface admits no CSRF-exempt verb, while the non-GET verbs keep the
    # paths and helpers routable for any external binding.
    let(:delete_surface) do
      Rails.application.routes.routes.select do |route|
        route.defaults[:controller] == 'camaleon_cms/admin/appearances' &&
          %w[widgets widget_delete].include?(route.defaults[:action].to_s)
      end
    end

    it 'admits no GET or HEAD on the widgets delete surface' do
      expect(delete_surface).not_to be_empty
      get_reachable = delete_surface.select do |route|
        verb = route.verb.to_s
        verb.empty? || verb.match?(/GET|HEAD/)
      end

      expect(get_reachable.map { |route| route.defaults[:action] }).to be_empty
    end

    it 'keeps the non-GET verbs routable' do
      verbs = delete_surface.to_h { |route| [route.defaults[:action].to_s, route.verb.to_s] }

      expect(verbs).to eq('widgets' => 'DELETE', 'widget_delete' => 'PATCH')
    end
  end

  describe 'logout' do
    it 'keeps the session on GET and shows a confirmation instead' do
      get '/admin/logout'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('You are about to end your session')

      get '/admin/profile/edit'
      expect(response).to have_http_status(:ok) # still signed in
    end

    it 'ends the session over POST' do
      post '/admin/logout'
      follow_redirect!

      get '/admin/profile/edit'
      expect(response).to redirect_to(cama_admin_login_path)
    end

    # Ecosystem themes (e_shop, efashion) link logout with return_to; the confirmation must carry
    # it into the POST, where the safe-redirect check vets it as on any logout.
    it 'carries return_to through the confirmation form' do
      get '/admin/logout', params: { return_to: 'http://www.example.com/somewhere' }

      expect(response.body).to include('return_to=http%3A%2F%2Fwww.example.com%2Fsomewhere')
    end

    # A multilingual theme may link logout with ?locale=; the confirmation POST must keep it so the
    # 'Session Closed' flash is rendered in the visitor's language, not the site default.
    it 'carries locale through the confirmation form' do
      get '/admin/logout', params: { locale: 'en' }

      expect(response.body).to include('locale=en')
    end

    # A crafted or mangled link can make either param arrive hash-shaped; carrying it straight into
    # the path helper would raise UnfilteredParameters (500). The confirmation must still render.
    it 'does not 500 when a param arrives hash-shaped' do
      get '/admin/logout', params: { return_to: { evil: 'x' }, full: { evil: 'x' } }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('You are about to end your session')
    end

    # The confirmation is HTML-only; a non-HTML GET (an ajax /admin/logout.json) must render it rather
    # than raise MissingTemplate (500), and must not end the session.
    it 'renders the confirmation for a .json GET instead of 500' do
      get '/admin/logout.json'

      expect(response).to have_http_status(:ok)

      get '/admin/profile/edit'
      expect(response).to have_http_status(:ok) # still signed in
    end

    # Security (audit M6): a logout POST carrying a stale CSRF token (a second tab that already reset
    # the session, or a cached page) must fall back to the confirmation, not a raw 422.
    it 'redirects a stale-token POST back to the confirmation instead of raising' do
      allow_any_instance_of(CamaleonCms::Admin::SessionsController)
        .to receive(:verify_authenticity_token).and_raise(ActionController::InvalidAuthenticityToken)

      post '/admin/logout'

      expect(response).to redirect_to(cama_admin_logout_path)
    end
  end
end
