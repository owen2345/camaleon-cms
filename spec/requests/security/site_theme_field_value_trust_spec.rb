# frozen_string_literal: true

# A role is trusted for the values that it saves through an action that its permissions allow. This
# trust ends at the gates of docs/security/permissions.md, and the scan of a custom field value at
# save is one of them. The scan trusts a holder of `settings` for the fields of the site, because
# that permission gives the trust of an administrator. It trusts a holder of `theme_settings` for
# the fields of a theme, because that permission allows the theme settings save. Such a role stores
# markup in those fields as written.
RSpec.describe 'Security: trust of site and theme field values', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  let(:script) { '<script>alert("field")</script>' }
  let(:role) { current_site.user_roles.create!(name: 'Site Manager', slug: 'site_mgr') }
  let(:manager) { create(:user, role: role.slug, site: current_site) }

  before do
    allow_any_instance_of(CamaleonCms::AdminController).to receive(:current_site).and_return(current_site)
  end

  def grant(*permissions)
    role.set_meta("_manager_#{current_site.id}", permissions.index_with(1))
    sign_in_as(manager, site: current_site)
  end

  def field_options(field, value)
    { '0' => { field.slug => { 'id' => field.id.to_s, 'values' => { '0' => value } } } }
  end

  it 'stores a script in a site field for a holder of settings' do
    group = current_site.custom_field_groups.create!(name: 'Site', slug: '_site-extra', object_class: 'Site',
                                                     objectid: current_site.id)
    field = group.add_manual_field({ 'name' => 'Footer', 'slug' => 'site_footer' }, { 'field_key' => 'text_box' })
    grant('settings')

    patch '/admin/settings/site_saved', params: {
      site: { name: current_site.name, slug: current_site.slug }, field_options: field_options(field, script)
    }

    expect(flash[:error]).to be_blank
    expect(CamaleonCms::Site.find(current_site.id).get_field_value('site_footer')).to eq(script)
  end

  it 'stores a script in a theme field for a holder of theme_settings' do
    theme = current_site.get_theme
    field = theme.add_field_group({ name: 'Theme', slug: '_theme-extra' })
                 .add_manual_field({ name: 'Footer', slug: 'theme_footer' }, { field_key: 'text_box' })
    grant('theme_settings')

    post '/admin/settings/save_theme', params: { field_options: field_options(field, script) }

    expect(flash[:error]).to be_blank
    expect(theme.get_field_value('theme_footer')).to eq(script)
  end
end
