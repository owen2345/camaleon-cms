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
  end
end
