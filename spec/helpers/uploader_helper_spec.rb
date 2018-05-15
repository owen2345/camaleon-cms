require 'rails_helper'
describe CamaleonCms::UploaderHelper do
  init_site
  before(:each) do
    @path = "#{CAMALEON_CMS_ROOT}/spec/support/fixtures/rails_tmp.png"
    FileUtils.cp("#{CAMALEON_CMS_ROOT}/spec/support/fixtures/rails.png", @path)
  end
  
  it "upload a local file" do
    expect(upload_file(File.open(@path)).keys.include?(:error)).not_to eql(true)
    expect(upload_file(File.open(@path), {thumb_size: '20x20'}).keys.include?(:error)).not_to eql(true)
    expect(upload_file(File.open(@path), {folder: 'sample'}).keys.include?(:error)).not_to eql(true)
  end
  
  it "upload a local file max size" do
    expect(upload_file(File.open(@path), {maximum: 1.byte}).keys.include?(:error)).to eql(true)
  end

  it "upload a local file custom dimension" do
    expect(upload_file(File.open(@path), {dimension: '50x50'}).keys.include?(:error)).not_to eql(true)
    expect(upload_file(File.open(@path), {dimension: 'x50'}).keys.include?(:error)).not_to eql(true)
    expect(upload_file(File.open(@path), {dimension: '50x'}).keys.include?(:error)).not_to eql(true)
    expect(upload_file(File.open(@path), {dimension: '50x20?'}).keys.include?(:error)).not_to eql(true)
  end

  it "upload a local file invalid format" do
    expect(upload_file(File.open(@path), {formats: 'audio'}).keys.include?(:error)).to eql(true)
  end

  it "upload a local file with versions" do
    expect(upload_file(File.open(@path), {versions: '300x300,505x350,20x'}).keys.include?(:error)).not_to eql(true)
  end
  
  it "add auto orient for cropping images" do
    callback = lambda do |params| 
      params[:img] = params[:img].auto_orient 
    end
    PluginRoutes.add_anonymous_hook('before_crop_image', callback, 'my_custom_hook')
    expect(upload_file(File.open(@path), {versions: '300x300,505x350,20x'}).keys.include?(:error)).not_to eql(true)
    PluginRoutes.remove_anonymous_hook('before_crop_image','my_custom_hook')
  end
  
  it "add auto orient for resizing" do
    callback = lambda do |params|
      params[:img] = params[:img].auto_orient 
    end
    PluginRoutes.add_anonymous_hook('before_resize_crop', callback, 'my_custom_hook')
    expect(upload_file(File.open(@path), {versions: '300x300,505x350,20x'}).keys.include?(:error)).not_to eql(true)
    PluginRoutes.remove_anonymous_hook('before_resize_crop','my_custom_hook')
  end

  it "upload a external file" do
    expect(upload_file('http://camaleon.tuzitio.com/media/132/slider/slide33.jpg').keys.include?(:error)).not_to eql(true)
  end 
  
end