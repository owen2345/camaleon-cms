# frozen_string_literal: true

# The media manager built HTML from two params of its page. The breadcrumb put each segment of the
# folder param into the HTML of its list, so a link ran markup when the page opened. The details of
# an image and the title of the image editor did the same with the dimension param, after a click on
# an image. The page must show both values as text.
RSpec.describe 'the params of the media manager page', :js do
  init_site

  let(:media_path) { "#{cama_root_relative_path}/admin/media" }

  before { admin_sign_in }

  it 'shows a folder param with markup as the text of the breadcrumb' do
    markup = '<img src=q onerror="window.mediaScriptRan=true">'
    visit "#{media_path}?#{{ folder: markup }.to_query}"

    expect(page).to have_css('.media_folder_breadcrumb li', exact_text: markup)
    expect(page).to have_no_css('.media_folder_breadcrumb img', visible: :all)
  end

  it 'keeps a link for each parent folder of the breadcrumb' do
    visit "#{media_path}?#{{ folder: '/photos/2026' }.to_query}"

    expect(page).to have_css(".media_folder_breadcrumb li a[data-path='/']")
    expect(page).to have_css(".media_folder_breadcrumb li a[data-path='/photos']", exact_text: 'photos')
    expect(page).to have_css('.media_folder_breadcrumb li span', exact_text: '2026')
  end

  # The value starts with a size, because the image editor reads the numbers of the param.
  it 'shows a dimension param with markup as text in the details and in the editor title' do
    dimension = '10x10<img src=q onerror="window.mediaScriptRan=true">'
    visit media_path
    attach_file('file_upload[]', "#{CAMALEON_CMS_ROOT}/spec/support/fixtures/rails.png", make_visible: true)
    wait_for_ajax
    visit "#{media_path}?#{{ dimension: dimension }.to_query}"

    page.execute_script("$('#cama_media_gallery .file_item.image_format').first().trigger('click')")
    expect(page).to have_css('.cdimension', text: dimension)
    expect(page).to have_no_css('.cdimension img', visible: :all)

    page.execute_script("$('#cama_media_gallery .file_item.image_format').first().find('.edit_item').trigger('click')")
    expect(page).to have_css('#media_panel_editor_image .modal-title', text: dimension)
    expect(page).to have_no_css('#media_panel_editor_image .modal-title img', visible: :all)
  end
end
