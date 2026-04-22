# frozen_string_literal: true

require 'rails_helper'

describe CamaleonCms::UploaderHelper do
  init_site

  before do
    @path = "#{CAMALEON_CMS_ROOT}/spec/support/fixtures/rails_tmp.png"
    FileUtils.cp("#{CAMALEON_CMS_ROOT}/spec/support/fixtures/rails.png", @path)
  end

  it 'upload a local file' do
    expect(upload_file(File.open(@path)).keys.include?(:error)).not_to eql(true)
    expect(upload_file(File.open(@path), { thumb_size: '20x20' }).keys.include?(:error)).not_to eql(true)
    expect(upload_file(File.open(@path), { folder: 'sample' }).keys.include?(:error)).not_to eql(true)
  end

  it 'upload a local file max size' do
    expect(upload_file(File.open(@path), { maximum: 1.byte }).keys.include?(:error)).to be(true)
  end

  describe 'deleting temporary uploaded file' do
    before { allow(CamaleonCmsUploader).to receive(:delete_block).and_call_original }

    it 'delete the uploaded file if temporal_time option is > 0' do
      # ensure the site uses the local filesystem for this test so the local uploader
      # receives the delete_file call
      current_site.set_option('filesystem_type', 'local')
      # replace the delete_block implementation for this example to avoid sleeping
      # using the provided helper which swaps the internal @delete_block for the
      # duration of the block
      with_delete_block(proc do |_settings, cama_uploader, file_key|
        cama_uploader.delete_file(file_key)
      end) do
        expect(CamaleonCmsUploader).to receive(:delete_block)
        expect_any_instance_of(CamaleonCmsLocalUploader).to receive(:delete_file)
        expect(upload_file(File.open(@path), { temporal_time: 1 }).keys.include?(:error)).to be(false)
      end
    end

    it "doesn't delete the uploaded file if temporal_time option is missing" do
      expect(CamaleonCmsUploader).not_to receive(:delete_block)
      expect_any_instance_of(CamaleonCmsLocalUploader).not_to receive(:delete_file)
      expect(upload_file(File.open(@path)).keys.include?(:error)).to be(false)
    end

    it "doesn't delete the uploaded file if temporal_time option is 0" do
      expect(CamaleonCmsUploader).not_to receive(:delete_block)
      expect_any_instance_of(CamaleonCmsLocalUploader).not_to receive(:delete_file)
      expect(upload_file(File.open(@path), { temporal_time: 0 }).keys.include?(:error)).to be(false)
    end

    it "doesn't delete the uploaded file if temporal_time option is < 0" do
      expect(CamaleonCmsUploader).not_to receive(:delete_block)
      expect_any_instance_of(CamaleonCmsLocalUploader).not_to receive(:delete_file)
      expect(upload_file(File.open(@path), { temporal_time: -1 }).keys.include?(:error)).to be(false)
    end
  end

  it 'upload a local file custom dimension' do
    expect(upload_file(File.open(@path), { dimension: '50x50' }).keys.include?(:error)).not_to eql(true)
    expect(upload_file(File.open(@path), { dimension: 'x50' }).keys.include?(:error)).not_to eql(true)
    expect(upload_file(File.open(@path), { dimension: '50x' }).keys.include?(:error)).not_to eql(true)
    expect(upload_file(File.open(@path), { dimension: '50x20?' }).keys.include?(:error)).not_to eql(true)
  end

  describe 'file upload with invalid path' do
    it "doesn't upload a local file with invalid path of a path traversal try" do
      expect(upload_file(File.open(@path), { folder: '../../config/initializers' }).keys.include?(:error)).to be(true)
    end

    it "doesn't upload a local file with invalid URI-like path" do
      expect(upload_file(File.open(@path), { folder: 'file:///config/initializers' }).keys.include?(:error)).to be(true)
    end
  end

  context 'with an absolute path' do
    let(:file) { File.join(current_site.upload_directory, '/tmp/config/initializers/rails_tmp.png') }

    after { File.delete(file) }

    it 'uploads a local file with an absolute path into the upload directory, not into the volume root' do
      expect(File).not_to exist(file)

      upload_file(File.open(@path), { folder: '/tmp/config/initializers' })

      expect(File).to exist(file)
    end
  end

  describe 'file upload with unsafe content' do
    let(:unsafe_file_path) { "#{CAMALEON_CMS_ROOT}/spec/support/fixtures/unsafe-test-xss.svg" }

    it "doesn't allow the file upload, returning an error" do
      expect(upload_file(File.open(unsafe_file_path), { folder: '/' })[:error])
        .to eql('Potentially malicious content found!')
    end

    it 'does not consume the Tempfile when scanning for suspicious content' do
      tmp = Tempfile.new(['cama-test'])
      begin
        tmp.binmode
        tmp.write('safe content')
        tmp.rewind

        helper_obj = Class.new { include CamaleonCms::UploaderHelper }.new

        # Call the private method via send to ensure we exercise the scanning logic
        expect(helper_obj.send(:file_content_unsafe?, tmp)).to be_nil

        # After scanning, the tempfile should still be readable (not at EOF)
        tmp.rewind
        expect(tmp.read).to eq('safe content')
      ensure
        tmp.close!
      end
    end
  end

  it "doesn't upload a local file with invalid format" do
    expect(upload_file(File.open(@path), { formats: 'audio' }).keys.include?(:error)).to be(true)
  end

  it 'upload a local file with versions' do
    expect(upload_file(File.open(@path), { versions: '300x300,505x350,20x' }).keys.include?(:error)).not_to eql(true)
  end

  it 'add auto orient for cropping images' do
    callback = lambda do |params|
      params[:img] = params[:img].auto_orient
    end
    PluginRoutes.add_anonymous_hook('before_crop_image', callback, 'my_custom_hook')
    expect(upload_file(File.open(@path), { versions: '300x300,505x350,20x' }).keys.include?(:error)).not_to eql(true)
    PluginRoutes.remove_anonymous_hook('before_crop_image', 'my_custom_hook')
  end

  it 'add auto orient for resizing' do
    callback = lambda do |params|
      params[:img] = params[:img].auto_orient
    end
    PluginRoutes.add_anonymous_hook('before_resize_crop', callback, 'my_custom_hook')
    expect(upload_file(File.open(@path), { versions: '300x300,505x350,20x' }).keys.include?(:error)).not_to eql(true)
    PluginRoutes.remove_anonymous_hook('before_resize_crop', 'my_custom_hook')
  end

  describe 'external URL upload safety' do
    let(:remote_url) { 'https://example.com/file.txt' }

    it 'blocks URLs rejected by UserUrlValidator before any network request' do
      allow(CamaleonCms::UserUrlValidator).to receive(:validate).with(remote_url).and_return(['blocked'])
      expect(Net::HTTP).not_to receive(:start)

      expect(upload_file(remote_url)[:error]).to include('blocked')
    end

    it 'blocks redirect responses to avoid SSRF bypasses' do
      redirect_response = Net::HTTPFound.new('1.1', '302', 'Found')
      redirect_response['location'] = 'http://127.0.0.1/private'
      http_client = instance_double(Net::HTTP, request: redirect_response)
      allow(http_client).to receive(:open_timeout=).with(10)
      allow(http_client).to receive(:read_timeout=).with(10)

      allow(CamaleonCms::UserUrlValidator).to receive(:validate).with(remote_url).and_return(true)
      allow(Net::HTTP).to receive(:start).and_yield(http_client)

      expect(upload_file(remote_url)[:error]).to eq('Redirects are not allowed for remote uploads.')
    end

    it 'uploads external files when URL is safe and HTTP response is successful' do
      ok_response = Net::HTTPOK.new('1.1', '200', 'OK')
      allow(ok_response).to receive(:body).and_return('plain text body')
      http_client = instance_double(Net::HTTP, request: ok_response)
      allow(http_client).to receive(:open_timeout=).with(10)
      allow(http_client).to receive(:read_timeout=).with(10)

      allow(CamaleonCms::UserUrlValidator).to receive(:validate).with(remote_url).and_return(true)
      allow(Net::HTTP).to receive(:start).and_yield(http_client)

      result = upload_file(remote_url)
      expect(result[:error]).to be_blank
      expect(result['url']).to be_present
    end

    it 'blocks remote files that exceed the site filesystem_max_size setting' do
      # Set the site limit to 10 bytes so we can trigger it with a small body.
      current_site.set_option('filesystem_max_size', 0.000001) # ~1 byte in megabytes

      oversized_body = 'x' * 1024
      ok_response = Net::HTTPOK.new('1.1', '200', 'OK')
      allow(ok_response).to receive(:body).and_return(oversized_body)
      http_client = instance_double(Net::HTTP, request: ok_response)
      allow(http_client).to receive(:open_timeout=).with(10)
      allow(http_client).to receive(:read_timeout=).with(10)

      allow(CamaleonCms::UserUrlValidator).to receive(:validate).with(remote_url).and_return(true)
      allow(Net::HTTP).to receive(:start).and_yield(http_client)

      result = upload_file(remote_url)
      expect(result[:error]).to include('Remote file too large')
    end
  end
end
