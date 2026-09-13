# frozen_string_literal: true

# A post's blank template/layout falls back to its post type's `default_template` / `default_layout`,
# which the frontend renders through the same `template_exists?` lookup. PostsController holds a
# non-admin's `meta[template]` to the offered list, but the post type option -- writable by a non-admin
# settings manager through `post_type_meta_params` -- was stored unchecked, an open route to the same
# admin-view sink. It is now held to the offered list too; administrators are not restricted.
RSpec.describe 'Security: post type default template/layout options', type: :request do
  init_site

  let(:post_type) { @site.post_types.find_by(slug: 'post') }
  let(:admin) { create(:user, role: 'admin', site: @site) }
  let(:settings_role) { @site.user_roles.create!(name: 'Settings manager', slug: 'settings-mgr-views') }
  let(:settings_manager) { create(:user, role: settings_role.slug, site: @site) }
  let(:admin_view) { 'camaleon_cms/admin/settings/site' }

  before { settings_role.set_meta("_manager_#{@site.id}", { 'settings' => 1 }) }

  def save_post_type(meta)
    patch "/admin/settings/post_types/#{post_type.id}",
          params: { post_type: { name: post_type.name, slug: post_type.slug }, meta: meta }
  end

  def stored_option(key)
    CamaleonCms::PostType.find(post_type.id).get_option(key)
  end

  describe 'a non-admin settings manager' do
    before { sign_in_as(settings_manager, site: @site) }

    it 'cannot set a default_template the editor does not offer' do
      save_post_type(default_template: admin_view)

      expect(response).to redirect_to(action: :index)
      expect(flash[:error]).to include('meta[default_template]')
      expect(stored_option('default_template')).to be_blank
    end

    it 'cannot set a default_layout the editor does not offer' do
      save_post_type(default_layout: 'camaleon_cms/admin')

      expect(flash[:error]).to include('meta[default_layout]')
      expect(stored_option('default_layout')).to be_blank
    end

    it 'may clear the option with a blank value' do
      save_post_type(default_template: '')

      expect(flash[:error]).to be_blank
      expect(stored_option('default_template')).to be_blank
    end
  end

  describe 'an administrator' do
    before { sign_in_as(admin, site: @site) }

    it 'may set a default_template outside the offered list' do
      save_post_type(default_template: admin_view)

      expect(flash[:error]).to be_blank
      expect(stored_option('default_template')).to eq(admin_view)
    end
  end
end
