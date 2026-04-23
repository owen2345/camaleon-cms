# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Plugin Attack Settings', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }

  before do
    current_site.plugins.where(slug: 'attack').first_or_create(set_meta: { status: 'active' })
  end

  context 'when user has plugins management permission' do
    let(:admin_role) { current_site.user_roles.create!(name: 'Plugin Admin', slug: 'plugin_admin') }
    let(:admin_user) { create(:user, role: admin_role.slug, site: current_site) }

    before do
      admin_role.set_meta("_manager_#{current_site.id}", { 'plugins' => 1 })
    end

    it 'allows access to attack settings' do
      sign_in_as(admin_user, site: current_site)

      get '/admin/plugins/attack/settings'

      expect(response).to have_http_status(200)
    end

    it 'allows saving attack settings' do
      sign_in_as(admin_user, site: current_site)

      post '/admin/plugins/attack/settings', params: {
        attack: { get_sec: '5', get_max: '10', post_sec: '20', post_max: '50', ban: '1', msg: 'Test message' }
      }

      expect(response).to redirect_to(%r{attack/settings})
      expect(flash[:notice]).to be_present
    end
  end

  context 'when user does NOT have plugins management permission' do
    let(:limited_role) { current_site.user_roles.create!(name: 'Limited User', slug: 'limited_user') }
    let(:limited_user) { create(:user, role: limited_role.slug, site: current_site) }

    before do
      limited_role.set_meta("_manager_#{current_site.id}", {})
    end

    it 'blocks access to attack settings' do
      sign_in_as(limited_user, site: current_site)

      get '/admin/plugins/attack/settings'

      expect(response).to redirect_to(/admin/)
      expect(flash[:error]).to be_present
    end

    it 'blocks saving attack settings' do
      sign_in_as(limited_user, site: current_site)

      post '/admin/plugins/attack/settings', params: {
        attack: { get_sec: '99', get_max: '99', post_sec: '99', post_max: '99', ban: '1', msg: 'Hacked' }
      }

      expect(response).to redirect_to(/admin/)
      expect(flash[:error]).to be_present
      expect(current_site.get_meta('attack_config')['get']['sec']).not_to eq('99')
    end
  end
end
