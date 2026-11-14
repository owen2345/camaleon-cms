# frozen_string_literal: true

# The media manager built HTML from the name and the URL of a file. The URL of a file holds the
# names of its folders, and an upload takes the folder from its request. So a role with the media
# permission can store a file in a folder with markup in its name. That markup then ran in the
# session of the admin who clicked the file. The media manager must show the name and the URL as
# text.
RSpec.describe 'the name and the URL of a file in the media manager', :js do
  init_site

  let(:markup) { '<img src=q onerror="return">' }
  let(:folder) { "a'b#{markup}" }
  let(:uploader) { CamaleonCmsLocalUploader.new(current_site: @site) }
  # The uploader stores a key as it is. An upload through the media manager cleans the file name.
  let(:image) do
    uploader.add_file("#{CAMALEON_CMS_ROOT}/spec/support/fixtures/rails.png", "/#{folder}/#{markup}.png",
                      same_name: true)
  end
  let(:first_file) { "$('#cama_media_gallery .file_item').first()" }

  before do
    admin_sign_in
    image
    visit "#{cama_root_relative_path}/admin/media?#{{ folder: "/#{folder}" }.to_query}"
  end

  after { FileUtils.rm_rf(File.join(uploader.instance_variable_get(:@root_folder), folder)) }

  # The image editor reads the image again with $.get and shows a message with the URL when that
  # request fails. The helper makes the request fail, and then opens the image editor.
  def open_image_editor_with_failed_request
    page.execute_script(<<~JS)
      $.get = function () {
        var request = $.Deferred().reject().promise();
        request.error = request.fail;
        return request;
      };
    JS
    page.execute_script("#{first_file}.find('.edit_item').trigger('click')")
  end

  it 'shows the name and the URL as text in the details of the file' do
    page.execute_script("#{first_file}.trigger('click')")

    expect(page).to have_css('.media_file_info .p_body a', exact_text: image['url'])
    expect(page.evaluate_script("$('.media_file_info .p_body a').attr('href')")).to eq(image['url'])
    expect(page).to have_css('.media_file_info .p_label span', exact_text: image['name'])
    expect(page).to have_no_css('.media_file_info .p_label img, .media_file_info .p_body img', visible: :all)
  end

  it 'shows the name as text in the title of the image editor, and the URL as the source of its image' do
    page.execute_script("#{first_file}.find('.edit_item').trigger('click')")

    expect(page).to have_css('#media_editable_image', visible: :all)
    expect(page.evaluate_script("$('#media_editable_image').attr('src')")).to eq(image['url'])
    expect(page).to have_css('#media_panel_editor_image .modal-title', text: image['name'])
    expect(page).to have_no_css('#media_panel_editor_image .modal-title img', visible: :all)
    expect(page).to have_no_css('#media_panel_editor_image [onerror]', visible: :all)
    # The cropper starts only after the image loads.
    expect(page).to have_css('#media_panel_editor_image .cropper-container', visible: :all, wait: 10)
  end

  it 'shows the URL as text in the message of a failed image request' do
    open_image_editor_with_failed_request

    expect(page).to have_css('#media_panel_editor_image .alert-danger li', text: image['url'], wait: 10)
    expect(page).to have_no_css('#media_panel_editor_image .alert-danger img', visible: :all)
  end

  # The URL of the file holds a replacement pattern of JavaScript. The message of a failed image
  # request must show that URL whole.
  context 'when a folder of the file holds a replacement pattern' do
    let(:folder) { 'a$&b' }

    it 'shows the whole URL in the message of a failed image request' do
      open_image_editor_with_failed_request

      expect(page).to have_css('#media_panel_editor_image .alert-danger li', text: image['url'], wait: 10)
    end
  end
end
