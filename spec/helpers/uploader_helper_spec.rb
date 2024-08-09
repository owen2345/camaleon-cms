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
      expect(CamaleonCmsUploader).to receive(:delete_block)
      expect_any_instance_of(CamaleonCmsLocalUploader).to receive(:delete_file)
      expect(upload_file(File.open(@path), { temporal_time: 1 }).keys.include?(:error)).to be(false)
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
    it 'upload a local file with invalid path of a path traversal try' do
      expect(upload_file(File.open(@path), { folder: '../../config/initializers' }).keys.include?(:error)).to be(true)
    end

    it 'upload a local file with invalid URI-like path' do
      expect(upload_file(File.open(@path), { folder: 'file:///config/initializers' }).keys.include?(:error)).to be(true)
    end

    it 'upload a local file with an absolute path' do
      expect(upload_file(File.open(@path), { folder: '/tmp/config/initializers' }).keys.include?(:error)).to be(true)
    end
  end

  it 'upload a local file with invalid format' do
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

  it 'upload a external file' do
    expect(
      upload_file('https://upload.wikimedia.org/wikipedia/commons/1/15/Jpegvergroessert.jpg').keys.include?(:error)
    ).not_to eql(true)
  end
end
