# frozen_string_literal: true

require 'rails_helper'

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
  end
end
