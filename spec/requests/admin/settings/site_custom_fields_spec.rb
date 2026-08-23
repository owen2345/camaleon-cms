# frozen_string_literal: true

# Regression coverage for https://github.com/owen2345/camaleon-cms/issues/1124
#
# A custom field group carries two independent foreign keys: `parent_id` (which site owns it) and
# `object_class` + `objectid` (which record's admin page displays it). The site settings page must
# read the second, so groups meant for posts, themes or menus never reach the site form -- their
# required fields would otherwise block the submit, and their values are discarded on save anyway.
RSpec.describe 'Admin site settings custom fields', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  let(:post_type) { current_site.post_types.first }

  let!(:site_group) do
    current_site.custom_field_groups.create!(
      name: 'Site Group', slug: '_site-group', object_class: 'Site', objectid: current_site.id
    )
  end

  let!(:post_type_group) do
    current_site.custom_field_groups.create!(
      name: 'Post Type Group', slug: '_post-type-group', object_class: 'PostType_Post', objectid: post_type.id
    )
  end

  let(:admin_role) { current_site.user_roles.create!(name: 'Settings Manager', slug: 'settings_manager') }
  let(:admin_user) { create(:user, role: admin_role.slug, site: current_site) }

  before do
    allow_any_instance_of(CamaleonCms::AdminController).to receive(:cama_authenticate)
    allow_any_instance_of(CamaleonCms::AdminController).to receive(:current_site).and_return(current_site)
    admin_role.set_meta("_manager_#{current_site.id}", { 'settings' => 1 })
    sign_in_as(admin_user, site: current_site)

    site_group.add_field({ 'name' => 'Site Field', 'slug' => 'site_field' }, { 'field_key' => 'text_box' })
    post_type_group.add_field({ 'name' => 'Post Type Field', 'slug' => 'post_type_field' },
                              { 'field_key' => 'text_box', 'required' => '1' })
  end

  describe 'GET /admin/settings/site' do
    it "renders the site's own custom fields" do
      get '/admin/settings/site'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('site_field')
    end

    it 'does not render custom fields belonging to other content types' do
      get '/admin/settings/site'

      expect(response.body).not_to include('post_type_field')
    end

    context 'when the site has no groups of its own' do
      before { site_group.destroy }

      it 'hides the custom configurations tab' do
        get '/admin/settings/site'

        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include('tab-other-configuration')
      end
    end
  end

  describe 'PATCH /admin/settings/site_saved' do
    it 'saves the site when a required field of another content type is left unfilled' do
      patch '/admin/settings/site_saved', params: {
        site: { name: 'Renamed Site', slug: current_site.slug, description: 'Updated description' },
        field_options: { '0' => { 'site_field' => { id: site_group.fields.first.id, values: { '0' => 'a value' } } } }
      }

      expect(response).to have_http_status(:found)
      expect(current_site.reload.name).to eq('Renamed Site')
      expect(current_site.get_field_value('site_field')).to eq('a value')
    end
  end
end
