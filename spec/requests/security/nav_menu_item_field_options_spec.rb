# frozen_string_literal: true

# The nav menu item save permitted the fields of groups placed as 'NavMenuItem', while the custom-fields
# form places a menu's groups as 'NavMenu' with the menu's id and the item's settings form renders
# exactly those. Every value submitted from that form was dropped; the external item options, permitted
# against the same set, likewise. The save now permits the fields of the groups placed on the item's
# menu, and only those: a group placed on another menu is not accepted.
RSpec.describe 'Nav menu item custom-field values are confined to the groups placed on its menu',
               type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  let(:admin) { create(:user, role: 'admin', site: current_site) }
  let(:menu) { current_site.nav_menus.create!(name: 'Own menu', slug: 'own-menu') }
  let(:other_menu) { current_site.nav_menus.create!(name: 'Other menu', slug: 'other-menu') }
  let(:item) { menu.append_menu_item({ label: 'Item', type: 'external', link: '#' }) }
  let!(:own) { register(group_on(menu, '_own-menu-fields'), 'own_menu') }
  let!(:sibling) { register(group_on(other_menu, '_other-menu-fields'), 'sibling_menu') }

  before do
    allow_any_instance_of(CamaleonCms::AdminController).to receive(:current_site).and_return(current_site)
    sign_in_as(admin, site: current_site)
  end

  # A group placed on the menu the way the custom-fields form stores its "NavMenu,<id>" choice.
  def group_on(nav_menu, slug)
    current_site.custom_field_groups.create!(name: slug.humanize, slug: slug, object_class: 'NavMenu',
                                             objectid: nav_menu.id)
  end

  def register(group, slug)
    group.add_manual_field({ 'name' => slug.humanize, 'slug' => slug }, { 'field_key' => 'text_box' })
  end

  it "stores a value for a field placed on the item's menu and drops another menu's" do
    post cama_admin_appearances_nav_menu_save_custom_settings_path(nav_menu_id: menu.id, id: item.id), params: {
      field_options: { '0' => {
        own.slug => { 'id' => own.id.to_s, 'values' => { '0' => 'own value' } },
        sibling.slug => { 'id' => sibling.id.to_s, 'values' => { '0' => 'sibling value' } }
      } }
    }

    expect(response).to have_http_status(:ok)
    expect(item.reload.get_field_value(own.slug)).to eq('own value')
    expect(item.custom_field_values.where(custom_field_slug: sibling.slug)).not_to exist
  end

  it "permits an external item's options against the same fields" do
    post cama_admin_appearances_nav_menu_update_menu_item_path(nav_menu_id: menu.id, id: item.id), params: {
      external_label: 'Item', external_url: '#', options: { own.slug => 'own option', sibling.slug => 'sibling option' }
    }

    expect(response).to have_http_status(:ok)
    expect(item.reload.get_option(own.slug)).to eq('own option')
    expect(item.get_option(sibling.slug)).to be_nil
  end
end
