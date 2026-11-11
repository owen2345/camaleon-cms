# frozen_string_literal: true

# The form of a new record checks the default options of a checkboxes custom field. A failed save
# renders the form again with the submitted values. These examples use a new category with the slug
# of an existing category, so the save fails on the server.
RSpec.describe 'the default options of a checkboxes custom field', :js do
  init_site

  let(:post_type) { @site.post_types.find_by!(slug: 'post') }
  let(:taken_slug) { post_type.categories.pick(:slug) }

  before do
    group = @site.custom_field_groups.create!(name: 'Category Group', slug: '_category-group',
                                              object_class: 'PostType_Category', objectid: post_type.id)
    group.add_manual_field(
      { 'name' => 'Colors', 'slug' => 'colors' },
      { 'field_key' => 'checkboxes',
        'multiple_options' => [{ 'title' => 'Option 1', 'value' => '1', 'default' => '1' },
                               { 'title' => 'Option 2', 'value' => '2' }] }
    )
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/post_type/#{post_type.id}/categories"
  end

  def submit_category(name:, slug:)
    within '#form-category' do
      yield if block_given?
      fill_in 'category_name', with: name
      fill_in 'category_slug', with: slug
      click_button 'Submit'
    end
  end

  it 'checks the default options on the form of a new record' do
    within '#form-category' do
      expect(page).to have_checked_field('Option 1')
      expect(page).to have_unchecked_field('Option 2')
    end
  end

  it 'shows the options that the admin checked after a failed save' do
    submit_category(name: 'Duplicate', slug: taken_slug) do
      uncheck 'Option 1'
      check 'Option 2'
    end

    expect(page).to have_text(I18n.t('camaleon_cms.admin.post.message.requires_different_slug'))
    within '#form-category' do
      expect(page).to have_unchecked_field('Option 1')
      expect(page).to have_checked_field('Option 2')
    end

    submit_category(name: 'Fixed', slug: 'fixed-category')

    expect(page).to have_css('.alert-success')
    expect(post_type.categories.find_by!(slug: 'fixed-category').get_field_values('colors')).to eq(%w[2])
  end
end
