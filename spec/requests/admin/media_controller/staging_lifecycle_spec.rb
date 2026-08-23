# frozen_string_literal: true

RSpec.describe CamaleonCms::Admin::MediaController, '#actions', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  let(:media_role) { current_site.user_roles.create!(name: 'Media Only', slug: 'media_only') }
  let(:media_user) { create(:user, role: media_role.slug, site: current_site) }
  let(:tmp_dir) { Rails.public_path.join('tmp', current_site.id.to_s) }

  before do
    media_role.set_meta("_manager_#{current_site.id}", { 'media' => 1 })
    allow_any_instance_of(described_class).to receive(:verify_media_authorization).and_return(true)
    sign_in_as(media_user, site: current_site)
    FileUtils.rm_rf(tmp_dir)
  end

  after { FileUtils.rm_rf(tmp_dir) }

  def staged_files
    Dir.glob("#{tmp_dir}/**/*").select { |f| File.file?(f) }
  end

  def data_uri(content, mime: 'text/html')
    "data:#{mime};base64,#{Base64.strict_encode64(content)}"
  end

  describe 'when the content scanner rejects the payload' do
    it 'reports the rejection and leaves nothing in the staging directory' do
      post '/admin/media/actions', params: {
        media_action: 'crop_url',
        url: data_uri('<html><script>alert(document.cookie)</script></html>'),
        name: 'stored_xss.html'
      }

      expect(response.body).to include('Potentially malicious content found!')
      expect(staged_files).to be_empty
    end

    it 'never creates the staged file at all' do
      # Stronger than the assertion above: with the scan moved ahead of the write,
      # the path is never created, so there is no window in which a concurrent
      # request could fetch /tmp/<site>/stored_xss.html.
      expect(File).not_to receive(:open).with(tmp_dir.join('stored_xss.html').to_s, 'wb')

      post '/admin/media/actions', params: {
        media_action: 'crop_url',
        url: data_uri('<html><script>alert(document.cookie)</script></html>'),
        name: 'stored_xss.html'
      }

      expect(response.body).to include('Potentially malicious content found!')
    end
  end

  describe 'when the payload exceeds the site size limit' do
    before { current_site.set_option('filesystem_max_size', 0.001) } # ~1 KB

    it 'rejects it without writing anything to the staging directory' do
      post '/admin/media/actions', params: {
        media_action: 'crop_url',
        url: data_uri('A' * 50_000, mime: 'image/png'),
        name: 'oversized.png'
      }

      expect(response.body).to include(I18n.t('camaleon_cms.common.file_size_exceeded'))
      expect(staged_files).to be_empty
    end

    it 'still accepts a payload within the limit' do
      png = File.binread("#{CAMALEON_CMS_ROOT}/spec/support/fixtures/rails.png")
      current_site.set_option('filesystem_max_size', 100)

      post '/admin/media/actions', params: {
        media_action: 'crop_url',
        url: data_uri(png, mime: 'image/png'),
        name: 'within_limit.png'
      }

      expect(response.body).not_to include(I18n.t('camaleon_cms.common.file_size_exceeded'))
    end
  end

  describe 'when the destination folder is invalid' do
    it 'removes the staged file' do
      png = File.binread("#{CAMALEON_CMS_ROOT}/spec/support/fixtures/rails.png")

      post '/admin/media/actions', params: {
        media_action: 'crop_url',
        url: data_uri(png, mime: 'image/png'),
        name: 'bad_folder.png',
        folder: '../../escape'
      }

      expect(staged_files).to be_empty
    end
  end

  describe 'when the format is rejected' do
    it 'removes the staged file' do
      post '/admin/media/actions', params: {
        media_action: 'crop_url',
        url: data_uri('harmless text', mime: 'text/plain'),
        name: 'notes.txt',
        formats: 'image'
      }

      expect(response.body).to include(I18n.t('camaleon_cms.common.file_format_error'))
      expect(staged_files).to be_empty
    end
  end

  describe 'when the upload succeeds' do
    after { FileUtils.rm_f(Rails.public_path.join('media', current_site.id.to_s, 'good_upload.png')) }

    it 'adds the file to the media library' do
      png = File.binread("#{CAMALEON_CMS_ROOT}/spec/support/fixtures/rails.png")

      post '/admin/media/actions', params: {
        media_action: 'crop_url',
        url: data_uri(png, mime: 'image/png'),
        name: 'good_upload.png'
      }

      expect(response).to have_http_status(:ok)
      expect(File.exist?(Rails.public_path.join('media', current_site.id.to_s, 'good_upload.png'))).to be(true)
    end
  end

  describe 'when no name is supplied' do
    # The staging guard reads the :name argument rather than params[:name]; the controller
    # forwards name: params[:name], so a blank parameter must still be rejected here.
    it 'reports the name-required error and stages nothing' do
      post '/admin/media/actions', params: {
        media_action: 'crop_url',
        url: data_uri('<p>hello</p>'),
        name: ''
      }

      expect(response.body).to include('File name is required')
      expect(staged_files).to be_empty
    end
  end
end
