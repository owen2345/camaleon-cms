# frozen_string_literal: true

RSpec.describe 'Plugin Front Cache Settings', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }

  before do
    current_site.plugins.where(slug: 'front_cache').first_or_create(set_meta: { status: 'active' })
    allow_any_instance_of(CamaleonCms::AdminController).to receive(:cama_authenticate)
    allow_any_instance_of(CamaleonCms::AdminController).to receive(:current_site).and_return(current_site)
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

      expect(response).to have_http_status(:ok)
    end

    it 'allows saving front_cache settings' do
      sign_in_as(admin_user, site: current_site)

      post '/admin/plugins/front_cache/settings', params: {
        cache: { paths: ['/test'], posts: ['1'], skip_posts: [], home: '1', cache_login: '0' }
      }

      expect(response).to redirect_to(%r{front_cache/settings})
      expect(flash[:notice]).to be_present
    end

    it 'cannot revert the invalidation version: the save only advances it (via its own POST bump)' do
      sign_in_as(admin_user, site: current_site)
      current_site.set_meta('front_cache_counter', 7)

      post '/admin/plugins/front_cache/settings', params: { cache: { paths: ['/test'], home: '1' } }

      # The settings POST itself triggers the admin_before_load invalidation bump (7 -> 8); the
      # save must not write the version back (the old wholesale settings write could revert a
      # concurrent bump, resurrecting a retired generation as servable).
      expect(current_site.get_meta('front_cache_counter')).to eq(8)
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
