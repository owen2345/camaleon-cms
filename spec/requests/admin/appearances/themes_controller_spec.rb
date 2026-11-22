# frozen_string_literal: true

RSpec.describe 'Admin::Appearances::ThemesController', type: :request do
  init_site
  let(:admin_user) do
    create(
      :user, username: 'admin', password: 'admin123', password_confirmation: 'admin123', role: 'admin', site: @site
    )
  end

  before { sign_in_as(admin_user, site: @site) }

  describe 'GET /admin/appearances/themes' do
    it 'does not call PluginRoutes.reload when viewing themes list' do
      expect(PluginRoutes).not_to receive(:reload)
      get cama_admin_appearances_themes_path
    end

    it 'returns success when viewing themes list' do
      get cama_admin_appearances_themes_path
      expect(response).to have_http_status(:success)
    end

    it 'calls PluginRoutes.reload when installing a theme' do
      # site_install_theme calls PluginRoutes.reload
      expect(PluginRoutes).to receive(:reload)
      get cama_admin_appearances_themes_path, params: { set: 'default' }
    end

    it 'redirects after installing a theme' do
      get cama_admin_appearances_themes_path, params: { set: 'default' }
      expect(response).to redirect_to(cama_admin_appearances_themes_path)
    end

    # The index action wrote the notice to flash.now, which the redirect drops.
    it 'shows the notice of the install on the page after the redirect' do
      get cama_admin_appearances_themes_path, params: { set: 'default' }
      follow_redirect!

      expect(response.body).to include('Theme updated')
    end

    # The theme switch is a GET request, and AdminController raises the error of a failed draw again
    # for a GET request. The list of the themes has no draw, so the redirect leads to a page that works.
    it 'redirects to the list with the error of the route file when the routes cannot be drawn' do
      break_the_routes("raise ArgumentError, '<b>broken</b>'")

      get cama_admin_appearances_themes_path, params: { set: 'default' }

      expect(response).to redirect_to(cama_admin_appearances_themes_path)
      expect(flash[:error]).to eq(I18n.t('camaleon_cms.admin.message.route_draw_failed_routes_kept',
                                         error: 'ArgumentError: &lt;b&gt;broken&lt;/b&gt;'))
      expect(flash[:notice]).to be_nil
      follow_redirect!
      expect(response).to have_http_status(:success)
    end

    it 'logs the error of the route file when the routes cannot be drawn' do
      break_the_routes
      allow(Rails.logger).to receive(:error)
      expect(Rails.logger).to receive(:error).with(/the routes cannot be drawn.*ArgumentError: broken plugin routes/m)

      get cama_admin_appearances_themes_path, params: { set: 'default' }
    end

    # The switch stores the theme before the on_active hook of the theme. A save of that hook can draw
    # the routes in its transaction, and a draw that fails rolls only that save back.
    it 'says that the routes stay as they were when a save of the on_active hook fails the draw' do
      break_the_routes
      site = @site
      allow_any_instance_of(CamaleonCms::Admin::Appearances::ThemesController).to receive(:hook_run) do |*args|
        site.post_types.create!(name: 'Books', slug: 'books') if args[-2] == 'on_active'
      end

      get cama_admin_appearances_themes_path, params: { set: 'camaleon_first' }

      expect(response).to redirect_to(cama_admin_appearances_themes_path)
      expect(flash[:error]).to eq(I18n.t('camaleon_cms.admin.message.route_draw_failed_routes_kept',
                                         error: 'ArgumentError: broken plugin routes'))
      expect(CamaleonCms::Site.find(@site.id).get_theme_slug).to eq('camaleon_first')
      expect(@site.post_types.where(slug: 'books')).to be_empty
    end
  end
end
