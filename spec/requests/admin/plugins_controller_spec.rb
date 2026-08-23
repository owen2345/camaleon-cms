# frozen_string_literal: true

RSpec.describe 'Admin::PluginsController', type: :request do
  init_site
  let(:admin_user) do
    create(
      :user, username: 'admin', password: 'admin123', password_confirmation: 'admin123', role: 'admin', site: @site
    )
  end

  before do
    sign_in_as(admin_user, site: @site)
  end

  describe 'GET /admin/plugins' do
    it 'does not call PluginRoutes.reload' do
      expect(PluginRoutes).not_to receive(:reload)
      get '/admin/plugins'
    end

    it 'returns success' do
      get '/admin/plugins'
      expect(response).to have_http_status(:success)
    end
  end

  describe 'GET /admin/plugins with reload' do
    before do
      # Stub plugin methods to avoid actual plugin operations
      allow_any_instance_of(CamaleonCms::Admin::PluginsController)
        .to receive(:plugin_install).and_return(double(title: 'Test Plugin', error: false))
      allow_any_instance_of(CamaleonCms::Admin::PluginsController)
        .to receive(:plugin_uninstall).and_return(double(title: 'Test Plugin', error: false))
      allow_any_instance_of(CamaleonCms::Admin::PluginsController)
        .to receive(:plugin_upgrade).and_return(double(title: 'Test Plugin', error: false))
    end

    it 'calls PluginRoutes.reload when toggling plugin (activate)' do
      expect(PluginRoutes).to receive(:reload)
      patch '/admin/plugins/toggle', params: { id: 'test_plugin', status: false }
    end

    it 'calls PluginRoutes.reload when toggling plugin (deactivate)' do
      expect(PluginRoutes).to receive(:reload)
      patch '/admin/plugins/toggle', params: { id: 'test_plugin', status: true }
    end

    it 'calls PluginRoutes.reload when upgrading plugin' do
      expect(PluginRoutes).to receive(:reload)
      post '/admin/plugins/test_plugin/upgrade'
    end

    it 'redirects after toggle' do
      patch '/admin/plugins/toggle', params: { id: 'test_plugin', status: false }
      expect(response).to redirect_to('/admin/plugins')
    end

    it 'redirects after upgrade' do
      post '/admin/plugins/test_plugin/upgrade'
      expect(response).to redirect_to('/admin/plugins')
    end
  end
end
