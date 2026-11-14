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

  # The breadcrumb joined only the first two slashes in a row, so a second pair gave an empty folder.
  it 'shows one item for each folder of a path with two slashes in a row at two places' do
    visit "#{media_path}?#{{ folder: '/photos//2026//may' }.to_query}"

    expect(page).to have_css(".media_folder_breadcrumb li a[data-path='/photos/2026']", exact_text: '2026')
    expect(page).to have_css('.media_folder_breadcrumb li span', exact_text: 'may')
    expect(page).to have_css('.media_folder_breadcrumb li', count: 4)
  end

  # The uploader puts an image into the list of the media manager, and the helper removes its file.
  def with_image_in_the_list
    uploader = CamaleonCmsLocalUploader.new(current_site: @site)
    uploader.add_file("#{CAMALEON_CMS_ROOT}/spec/support/fixtures/rails.png", '/rails.png', same_name: true)
    yield
  ensure
    FileUtils.rm_f(File.join(uploader.instance_variable_get(:@root_folder), 'rails.png')) if uploader
  end

  def open_image_editor
    page.execute_script("$('#cama_media_gallery .file_item.image_format').first().find('.edit_item').trigger('click')")
  end

  # The value starts with a size, because the image editor reads the numbers of the param.
  it 'shows a dimension param with markup as text in the details and in the editor title' do
    dimension = "10x10#{markup}"
    with_image_in_the_list do
      visit "#{media_path}?#{{ dimension: dimension }.to_query}"

      page.execute_script("$('#cama_media_gallery .file_item.image_format').first().trigger('click')")
      expect(page).to have_css('.cdimension', text: dimension)
      expect(page).to have_no_css('.cdimension img', visible: :all)

      open_image_editor
      expect(page).to have_css('#media_panel_editor_image .modal-title', text: dimension)
      expect(page).to have_no_css('#media_panel_editor_image .modal-title img', visible: :all)
    end
  end

  # The image editor reads a number from each part of the param. A part with no digit gave no
  # number, and the code that starts the editor stopped there.
  it 'starts the image editor with no size limit for a dimension param with no digit' do
    with_image_in_the_list do
      visit "#{media_path}?dimension=abc"
      open_image_editor

      expect(page).to have_css('#media_panel_editor_image .cropper-container', visible: :all, wait: 10)
      expect(page).to have_no_css('#media_panel_editor_image .with_image[readonly]')
    end
  end

  it 'keeps the width of a dimension param whose height has no digit' do
    with_image_in_the_list do
      visit "#{media_path}?dimension=30xabc"
      open_image_editor

      expect(page).to have_css('#media_panel_editor_image .cropper-container', visible: :all, wait: 10)
      expect(page).to have_css('#media_panel_editor_image .with_image[readonly]')
      expect(find('#media_panel_editor_image .with_image').value).to eq('30')
      expect(page).to have_no_css('#media_panel_editor_image .height_image[readonly]')
    end
  end
end
