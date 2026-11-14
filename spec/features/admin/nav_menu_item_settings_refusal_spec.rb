# frozen_string_literal: true

# The nav menu item settings modal posts its form by XHR. A refused custom-field value answered with a
# redirect, so the script got the admin page, alerted it and closed the modal as if the save had
# passed. These examples drive the real modal as a user who is not an administrator: a refused value
# keeps the modal open and shows the refusal, and a stored value closes it.
RSpec.describe 'the nav menu item settings modal', :js do
  init_site

  let(:menu) { @site.nav_menus.first }
  let(:item) { menu.append_menu_item({ label: 'Settings item', type: 'external', link: '#' }) }
  let(:refusal) { I18n.t('camaleon_cms.admin.custom_field.message.value_rejected_html', slug: 'menu_attr') }

  before do
    group = @site.custom_field_groups.create!(name: 'Menu fields', slug: '_menu-item-settings',
                                              object_class: 'NavMenu', objectid: menu.id)
    group.add_manual_field({ 'name' => 'Attribute', 'slug' => 'menu_attr' }, { 'field_key' => 'field_attrs' })
    role = @site.user_roles.create!(name: 'Menu manager', slug: 'menu-manager-modal')
    role.set_meta("_manager_#{@site.id}", { 'nav_menu' => 1 })
    create(:user, role: role.slug, site: @site, username: 'menu_manager')
    item
    admin_sign_in('menu_manager', '12345678')
  end

  def open_item_settings
    visit "#{cama_root_relative_path}/admin/appearances/nav_menus?id=#{menu.id}"
    find("#menus_list .dd-item[data-id='#{item.id}'] .custom_settings_link").click
    wait_for_visible_modal
  end

  # In some CI jobs, the mouse click on Submit did not reach the button, and the server got no
  # request. The cause is not known. So the helper presses the button in the page, as the image
  # preview spec does for its remove button.
  def save_attribute(value)
    within '#ow_inline_modal' do
      find('.input-attr').set('data-note')
      find('.input-value').set(value)
      find_button('Submit').execute_script('this.click()')
    end
  end

  it 'shows a refused value in the modal and keeps the modal open' do
    open_item_settings
    save_attribute('<script>alert(1)</script>')

    within '#ow_inline_modal' do
      expect(page).to have_css('.cama_save_refusal', text: refusal)
    end
    expect(item.reload.get_field_value('menu_attr')).to be_blank
  end

  # A 422 that is not a refusal: production answers a CSRF failure with public/422.html. The modal
  # shows a generic message, not the source of that page.
  it 'shows a generic message for a 422 that is not a refusal' do
    open_item_settings
    allow_any_instance_of(CamaleonCms::NavMenuItem)
      .to receive(:set_field_values).and_raise(ActionController::InvalidAuthenticityToken)

    with_production_error_pages do
      save_attribute('plain note')

      within '#ow_inline_modal' do
        expect(page).to have_css('.cama_save_refusal', text: 'The settings could not be saved')
      end
    end
    expect(page).to have_no_css('.cama_save_refusal', text: 'rejected')
  end

  it 'stores a value and closes the modal' do
    open_item_settings
    save_attribute('plain note')

    expect(page).to have_no_css('#ow_inline_modal')
    expect(item.reload.get_field_value('menu_attr').to_s).to include('plain note')
  end
end
