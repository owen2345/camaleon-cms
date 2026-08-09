# frozen_string_literal: true

require 'rails_helper'

# Unit-drives the SVG→JPG rename convention with real ImageMagick conversions (CI installs
# ImageMagick). The upload pipeline preserves the client's extension case, so an uppercase
# `logo.SVG` must take the same convert-to-JPEG path as `logo.svg`; the previous case-sensitive
# guard skipped the conversion and wrote an SVG-format artifact back to the `.SVG` path.
RSpec.describe CamaleonCms::UploaderImageProcessing do
  let(:host_class) do
    Class.new do
      include CamaleonCms::UploaderImageProcessing

      attr_accessor :cama_uploader

      def hooks_run(*_args); end

      def uploader_verify_name(path)
        path
      end
    end
  end
  let(:host) { host_class.new }
  let(:fixture_svg) { File.read("#{CAMALEON_CMS_ROOT}/spec/support/fixtures/svg-safe.svg") }

  around do |example|
    Dir.mktmpdir('cama-svg-crop') do |dir|
      @tmpdir = dir
      example.run
    end
  end

  # cama_resize_and_crop renames the path in place (sub!), so hand it a mutable copy.
  def stage_svg(name)
    path = File.join(@tmpdir, name)
    File.write(path, fixture_svg)
    path
  end

  describe '#cama_resize_and_crop' do
    it 'converts an uppercase .SVG to a JPEG artifact (case-insensitive rename)' do
      res = host.cama_resize_and_crop(stage_svg('logo.SVG'), '50', '50')

      expect(res).to end_with('logo.jpg')
      expect(File.binread(res, 3)).to eq("\xFF\xD8\xFF".b)
    end

    it 'converts a lowercase .svg the same way' do
      res = host.cama_resize_and_crop(stage_svg('logo.svg'), '50', '50')

      expect(res).to end_with('logo.jpg')
      expect(File.binread(res, 3)).to eq("\xFF\xD8\xFF".b)
    end

    it 'leaves a non-SVG path un-renamed' do
      png = File.join(@tmpdir, 'photo.png')
      FileUtils.cp("#{CAMALEON_CMS_ROOT}/spec/support/fixtures/rails.png", png)

      expect(host.cama_resize_and_crop(png, '10', '10')).to end_with('photo.png')
    end
  end

  describe '#cama_uploader_generate_thumbnail' do
    it 'derives a .jpg thumb key from an uppercase .SVG source' do
      uploader = instance_double(CamaleonCmsLocalUploader)
      allow(uploader).to receive(:version_path).with('/media/1/logo.SVG')
                                               .and_return('/media/1/thumb/logo-svg.SVG')
      host.cama_uploader = uploader

      expect(uploader).to receive(:add_file)
        .with(kind_of(String), '/media/1/thumb/logo-svg.jpg', hash_including(is_thumb: true, same_name: true))

      host.cama_uploader_generate_thumbnail(stage_svg('logo.SVG'), '/media/1/logo.SVG', '40x40')
    end
  end
end
