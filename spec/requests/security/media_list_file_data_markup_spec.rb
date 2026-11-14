# frozen_string_literal: true

# The list of the media manager gives the data of each file to its script as JSON in a hidden
# textarea. The view wrote that JSON with no HTML escape. Rails writes the < and the & of JSON as
# escapes, and a host app can turn that setting off. The URL of a file holds the names of its
# folders. With the setting off, a folder name with a closing textarea tag then ended the textarea.
# The markup after it became a part of the page. The view must write the JSON as text.
RSpec.describe 'the file data in the list of the media manager', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  # The two folders give the text </textarea> and an img tag in the URL of the file.
  let(:folder) { 'x</textarea><img src=q onerror="return">' }
  let(:uploader) { CamaleonCmsLocalUploader.new(current_site: current_site) }
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
    sign_in_as(create(:user, role: 'admin', site: current_site), site: current_site)
    image
    get '/admin/media', params: { folder: "/#{folder}" }
  end

  after { FileUtils.rm_rf(File.join(uploader.instance_variable_get(:@root_folder), 'x<')) }

  # An HTML5 parser reads the page as a browser does.
  it 'adds no element from the URL of a file, and holds the whole URL in the data of the file' do
    list = Nokogiri::HTML5.parse(response.body).at_css('#cama_media_gallery')

    expect(list.css('img[onerror]')).to be_empty
    expect(JSON.parse(list.at_css('.file_item textarea.data_value').text)['url']).to eq(image['url'])
  end
end
