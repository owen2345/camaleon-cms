# frozen_string_literal: true

# The list of the media manager gives the data of each file to its script as JSON in a hidden
# textarea. The view wrote that JSON with no HTML escape. Rails writes the < and the & of JSON as
# escapes, and a host app can turn that setting off. The URL of a file holds the names of its
# folders. With the setting off, a folder name with a closing textarea tag then ended the textarea,
# and the markup after it became a part of the page. The view must write the JSON as text.
RSpec.describe 'the file data in the list of the media manager', :js do
  init_site

  # The two folders give the text </textarea> and an img tag in the URL of the file.
  let(:folder) { 'x</textarea><img src=q onerror="return">' }
  let(:uploader) { CamaleonCmsLocalUploader.new(current_site: @site) }
  let(:image) do
    uploader.add_file("#{CAMALEON_CMS_ROOT}/spec/support/fixtures/rails.png", "/#{folder}/rails.png", same_name: true)
  end

  around do |example|
    saved = ActiveSupport::JSON::Encoding.escape_html_entities_in_json
    ActiveSupport::JSON::Encoding.escape_html_entities_in_json = false
    example.run
  ensure
    ActiveSupport::JSON::Encoding.escape_html_entities_in_json = saved
  end

  before do
    admin_sign_in
    image
    visit "#{cama_root_relative_path}/admin/media?#{{ folder: "/#{folder}" }.to_query}"
  end

  after { FileUtils.rm_rf(File.join(uploader.instance_variable_get(:@root_folder), 'x<')) }

  it 'adds no element from the URL of a file, and gives the whole URL to the script' do
    expect(page).to have_css('#cama_media_gallery .file_item')
    expect(page).to have_no_css('#cama_media_gallery img[onerror]', visible: :all)

    page.execute_script("$('#cama_media_gallery .file_item').first().trigger('click')")
    expect(page).to have_css('.media_file_info .p_body a', exact_text: image['url'])
  end
end
