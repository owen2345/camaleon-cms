# frozen_string_literal: true

# The image field of the custom-field form shows a preview of its URL. The preview code put the URL
# into the HTML of the preview. So a value with a quote and a tag added that tag to the admin form,
# and its event handler ran. The save of an image value refuses only a script URL, so an author who
# is not an administrator can store such a value. The preview must set the URL as attribute values.
RSpec.describe 'the image preview of a custom field', :js do
  init_site

  let(:post_type) { @site.post_types.find_by!(slug: 'post') }
  let(:image_url) { 'x"><img src=x onerror="window.previewScriptRan=true">' }

  before do
    group = @site.custom_field_groups.create!(name: 'Image fields', slug: '_image-preview-fields',
                                              object_class: 'PostType_Post', objectid: post_type.id)
    group.add_manual_field({ 'name' => 'Photo', 'slug' => 'photo' }, { 'field_key' => 'image' })
    admin_sign_in
  end

  # An onerror handler runs only after its image fails to load. So the example does not wait for the
  # handler: it checks that no element of the field group has one.
  it 'shows the stored URL as the link and the image of the preview, and adds no other element' do
    post = create(:post, post_type: post_type, owner: CamaleonCms::User.find_by!(username: 'admin'))
    post.set_field_value('photo', image_url)

    visit "#{cama_root_relative_path}/admin/post_type/#{post_type.id}/posts/#{post.id}/edit"

    expect(page).to have_css('.custom_field_image_preview', visible: :all)
    expect(page).to have_css('.custom_field_image_preview *', count: 2, visible: :all)
    expect(page.evaluate_script("$('.custom_field_image_preview a').attr('href')")).to eq(image_url)
    expect(page.evaluate_script("$('.custom_field_image_preview img').attr('src')")).to eq(image_url)
    expect(page).to have_no_css('.c-field-group [onerror]', visible: :all)
  end

  # The upload button sets a new URL and triggers the change event of the field, as this example does.
  # The URLs are data URLs, so the browser sends no request for them to the test server.
  it 'replaces the preview when the URL changes' do
    first_url = 'data:image/gif;base64,R0lGODlhAQABAAAAACw='
    second_url = 'data:image/gif;base64,R0lGODlhAQABAIAAAP///wAAACw='
    post = create(:post, post_type: post_type, owner: CamaleonCms::User.find_by!(username: 'admin'))
    post.set_field_value('photo', first_url)

    visit "#{cama_root_relative_path}/admin/post_type/#{post_type.id}/posts/#{post.id}/edit"
    expect(page).to have_css('.custom_field_image_preview', visible: :all)
    page.execute_script("$('.custom_field_image_preview').closest('.input-group').find('input')" \
                        ".val('#{second_url}').trigger('change')")

    expect(page).to have_css('.custom_field_image_preview', count: 1, visible: :all)
    expect(page.evaluate_script("$('.custom_field_image_preview a').attr('href')")).to eq(second_url)
  end

  it 'removes the preview when the remove button empties the URL' do
    post = create(:post, post_type: post_type, owner: CamaleonCms::User.find_by!(username: 'admin'))
    post.set_field_value('photo', 'data:image/gif;base64,R0lGODlhAQABAAAAACw=')

    visit "#{cama_root_relative_path}/admin/post_type/#{post_type.id}/posts/#{post.id}/edit"
    find('.custom_field_image_preview', visible: :all).ancestor('.input-group').find('.btn-primary').click

    expect(page).to have_no_css('.custom_field_image_preview', visible: :all)
    expect(find('.c-field-image input.input-value').value).to eq('')
  end
end
