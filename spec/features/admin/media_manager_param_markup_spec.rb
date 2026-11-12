# frozen_string_literal: true

# The media manager built HTML from two params of its page. The breadcrumb put each segment of the
# folder param into the HTML of its list, so a link ran markup when the page opened. The details of
# an image and the title of the image editor did the same with the dimension param, after a click on
# an image. The page must show both values as text.
RSpec.describe 'the params of the media manager page', :js do
  init_site

  let(:media_path) { "#{cama_root_relative_path}/admin/media" }
  let(:markup) { '<img src=q onerror="return">' }

  before { admin_sign_in }

  it 'shows a folder param with markup as the text of the breadcrumb' do
    visit "#{media_path}?#{{ folder: markup }.to_query}"

    expect(page).to have_css('.media_folder_breadcrumb li', exact_text: markup)
    expect(page).to have_no_css('.media_folder_breadcrumb img', visible: :all)
  end

  # The breadcrumb shows a parent folder as a link, with the path of the folder in data-path.
  it 'shows a parent folder with markup or a quote as the text of its link' do
    visit "#{media_path}?#{{ folder: "/a'b/#{markup}/2026" }.to_query}"

    expect(page).to have_css('.media_folder_breadcrumb li a', exact_text: markup)
    expect(page).to have_css(%(.media_folder_breadcrumb li a[data-path="/a'b"]), exact_text: "a'b")
    expect(page).to have_no_css('.media_folder_breadcrumb img', visible: :all)
  end

  it 'keeps a link for each parent folder of the breadcrumb' do
    visit "#{media_path}?#{{ folder: '/photos/2026' }.to_query}"

    expect(page).to have_css(".media_folder_breadcrumb li a[data-path='/']")
    expect(page).to have_css(".media_folder_breadcrumb li a[data-path='/photos']", exact_text: 'photos')
    expect(page).to have_css('.media_folder_breadcrumb li span', exact_text: '2026')
  end

  # The value starts with a size, because the image editor reads the numbers of the param. The
  # uploader puts an image into the list of the media manager, and the example removes its file.
  it 'shows a dimension param with markup as text in the details and in the editor title' do
    dimension = "10x10#{markup}"
    uploader = CamaleonCmsLocalUploader.new(current_site: @site)
    uploader.add_file("#{CAMALEON_CMS_ROOT}/spec/support/fixtures/rails.png", '/rails.png', same_name: true)
    visit "#{media_path}?#{{ dimension: dimension }.to_query}"

    page.execute_script("$('#cama_media_gallery .file_item.image_format').first().trigger('click')")
    expect(page).to have_css('.cdimension', text: dimension)
    expect(page).to have_no_css('.cdimension img', visible: :all)

    page.execute_script("$('#cama_media_gallery .file_item.image_format').first().find('.edit_item').trigger('click')")
    expect(page).to have_css('#media_panel_editor_image .modal-title', text: dimension)
    expect(page).to have_no_css('#media_panel_editor_image .modal-title img', visible: :all)
  ensure
    FileUtils.rm_f(File.join(uploader.instance_variable_get(:@root_folder), 'rails.png')) if uploader
  end
end
