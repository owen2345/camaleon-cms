# frozen_string_literal: true

# The form of a custom field group shows a help text for the placement of the group. The form code
# put that text into HTML, and the help of a category holds the name of the category. An Editor can
# store a category name with markup. That markup then ran in the session of the admin who opened a
# group of that category. The form must show the help as text.
RSpec.describe 'the placement help of the custom field group form', :js do
  init_site

  let(:post_type) { @post.post_type }
  let(:help) { '#select_assign_group_help' }

  before { admin_sign_in }

  def open_group(object_class, objectid)
    group = CamaleonCms::CustomFieldGroup.create!(name: 'Notes', slug: 'notes', object_class: object_class,
                                                  objectid: objectid, parent_id: @site.id)
    visit "#{cama_root_relative_path}/admin/settings/custom_fields/#{group.id}/edit"
  end

  it 'shows a category name with markup as text' do
    markup = '<img src=q onerror="return">'
    category = post_type.categories.create!(name: markup, slug: 'markup')
    open_group('Category_Post', category.id)

    expect(page).to have_css(help, text: markup)
    expect(page).to have_no_css("#{help} img", visible: :all)
  end

  # The help of a post type showed its name as it is before the fix too.
  it 'shows a post type name with markup as it is' do
    name = "Ben & Jerry's <b>x</b>"
    post_type.update!(name: name)
    open_group('PostType_Post', post_type.id)

    expect(page).to have_css(help, text: name)
    expect(page).to have_no_css("#{help} b", visible: :all)
  end
end
