# frozen_string_literal: true

# The form of a custom field group shows the name of each field in the title of the panel of that
# field. A change of the name input wrote the name into that title as HTML. A role with the
# custom_fields permission can store a field name with markup. That markup then ran in the session
# of the admin who changed the name. The form must show the name as text.
RSpec.describe 'the field title of the custom field group form', :js do
  init_site

  let(:markup) { '<img src=q onerror="return">' }
  let(:title) { '#sortable-fields .panel-item .span-title' }

  before do
    admin_sign_in
    group = CamaleonCms::CustomFieldGroup.create!(name: 'Notes', slug: 'notes', object_class: 'Site',
                                                  objectid: @site.id, parent_id: @site.id)
    group.add_manual_field({ 'name' => markup, 'slug' => 'note' }, { 'field_key' => 'text_box' })
    visit "#{cama_root_relative_path}/admin/settings/custom_fields/#{group.id}/edit"
  end

  it 'shows a field name with markup as text when the admin changes the name' do
    find('#sortable-fields .text-title').send_keys('!')

    expect(page).to have_css(title, exact_text: "#{markup}!")
    expect(page).to have_no_css("#{title} img", visible: :all)
  end
end
