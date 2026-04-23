# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Plugin Front Cache Settings', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }

  before do
    current_site.plugins.where(slug: 'front_cache').first_or_create(set_meta: { status: 'active' })
  end

  context 'when user has plugins management permission' do
    let(:admin_role) { current_site.user_roles.create!(name: 'Plugin Admin', slug: 'plugin_admin') }
    let(:admin_user) { create(:user, role: admin_role.slug, site: current_site) }

    before do
      admin_role.set_meta("_manager_#{current_site.id}", { 'plugins' => 1 })
    end

    it 'allows access to front_cache settings' do
      sign_in_as(admin_user, site: current_site)

      get '/admin/plugins/front_cache/settings'

      expect(response).to have_http_status(200)
    end

    it 'allows saving front_cache settings' do
      sign_in_as(admin_user, site: current_site)

      post '/admin/plugins/front_cache/settings', params: {
        cache: { paths: ['/test'], posts: ['1'], skip_posts: [], home: '1', cache_login: '0' }
      }

      expect(response).to redirect_to(/front_cache\/settings/)
      expect(flash[:notice]).to be_present
    end
  end

  context 'when user does NOT have plugins management permission' do
    let(:limited_role) { current_site.user_roles.create!(name: 'Limited User', slug: 'limited_user') }
    let(:limited_user) { create(:user, role: limited_role.slug, site: current_site) }

    before do
      limited_role.set_meta("_manager_#{current_site.id}", {})
    end

    it 'blocks access to front_cache settings' do
      sign_in_as(limited_user, site: current_site)

      get '/admin/plugins/front_cache/settings'

      expect(response).to redirect_to(/admin/)
      expect(flash[:error]).to be_present
    end

    it 'blocks saving front_cache settings' do
      sign_in_as(limited_user, site: current_site)

      post '/admin/plugins/front_cache/settings', params: {
        cache: { paths: ['/hacked'], cache_login: '1' }
      }

      expect(response).to redirect_to(/admin/)
      expect(flash[:error]).to be_present
      cached = current_site.get_meta('front_cache_elements')
      expect(cached[:paths]).not_to include('/hacked')
    end
  end
end