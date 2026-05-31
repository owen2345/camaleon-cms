# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CamaleonCmsLocalUploader do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  let(:uploader) { described_class.new(current_site: current_site) }

  context 'with an invalid path containing path traversal characters' do
    describe '#add_folder' do
      it 'returns an error' do
        expect(uploader.add_folder('../tmp')).to eql(error: 'Invalid folder path')
      end
    end

    describe '#delete_folder' do
      it 'returns an error' do
        expect(uploader.delete_folder('../tmp')).to eql(error: 'Invalid folder path')
      end
    end

    describe '#delete_file' do
      it 'returns an error' do
        expect(uploader.delete_file('../test.rb')).to eql(error: 'Invalid file path')
      end
    end
  end

  describe '#cama_compat_legacy_thumb (backwards-compat for legacy PNG thumbnails)' do
    let(:root_folder) { uploader.instance_variable_get(:@root_folder) }
    let(:thumb_dir) { File.join(root_folder, 'media', 'thumb') }
    let(:thumb_key) { '/media/thumb/photo-jpg.jpg' }
    let(:thumb_url) { '/media/1/thumb/photo-jpg.jpg' }

    before { FileUtils.mkdir_p(thumb_dir) }
    after { FileUtils.rm_rf(File.join(root_folder, 'media')) }

    it 'rewrites the thumb url to the legacy .png when only the .png exists on disk' do
      File.write(File.join(thumb_dir, 'photo-jpg.png'), 'x')

      expect(uploader.send(:cama_compat_legacy_thumb, thumb_url, thumb_key))
        .to eq('/media/1/thumb/photo-jpg.png')
    end

    it 'keeps the computed thumb url when the matching file exists on disk' do
      File.write(File.join(thumb_dir, 'photo-jpg.jpg'), 'x')

      expect(uploader.send(:cama_compat_legacy_thumb, thumb_url, thumb_key)).to eq(thumb_url)
    end

    it 'keeps the computed thumb url when neither the computed nor the .png variant exist' do
      expect(uploader.send(:cama_compat_legacy_thumb, thumb_url, thumb_key)).to eq(thumb_url)
    end

    it 'leaves a .png source thumb untouched' do
      png_url = '/media/1/thumb/photo-png.png'
      png_key = '/media/thumb/photo-png.png'

      expect(uploader.send(:cama_compat_legacy_thumb, png_url, png_key)).to eq(png_url)
    end

    it 'returns a blank thumb url unchanged' do
      expect(uploader.send(:cama_compat_legacy_thumb, '', thumb_key)).to eq('')
    end

    it 'falls back to the original file url when no thumbnail exists on disk (sample: .ico favicon)' do
      ico_key = '/media/thumb/favicon-ico.ico'
      ico_thumb = '/media/1/thumb/favicon-ico.ico'
      original = '/media/1/favicon.ico'

      expect(uploader.send(:cama_compat_legacy_thumb, ico_thumb, ico_key, original)).to eq(original)
    end
  end

  describe '#objects (legacy thumbnail fallback for cached media records)' do
    let(:root_folder) { uploader.instance_variable_get(:@root_folder) }
    let(:thumb_dir) { File.join(root_folder, 'thumb') }
    let(:collection) { uploader.send(:get_media_collection) }

    before { FileUtils.mkdir_p(thumb_dir) }
    after { FileUtils.rm_rf(thumb_dir) }

    def create_image_media(thumb)
      collection.create!(name: 'photo.jpg', folder_path: '/', is_folder: false, is_public: false,
                         file_type: 'image', url: '/media/1/photo.jpg', thumb: thumb)
    end

    it 'rewrites cached .jpg thumb urls to the on-disk legacy .png' do
      File.write(File.join(thumb_dir, 'photo-jpg.png'), 'x')
      create_image_media('/media/1/thumb/photo-jpg.jpg')

      item = uploader.objects('/').find { |i| i['name'] == 'photo.jpg' }
      expect(item['thumb']).to eq('/media/1/thumb/photo-jpg.png')
    end

    it 'keeps the cached thumb url when the matching file exists on disk' do
      File.write(File.join(thumb_dir, 'photo-jpg.jpg'), 'x')
      create_image_media('/media/1/thumb/photo-jpg.jpg')

      item = uploader.objects('/').find { |i| i['name'] == 'photo.jpg' }
      expect(item['thumb']).to eq('/media/1/thumb/photo-jpg.jpg')
    end

    it 'falls back to the original file url for a cached item with no thumbnail on disk (favicon)' do
      collection.create!(name: 'favicon.ico', folder_path: '/', is_folder: false, is_public: false,
                         file_type: 'image', url: '/media/1/favicon.ico',
                         thumb: '/media/1/thumb/favicon-ico.ico')

      item = uploader.objects('/').find { |i| i['name'] == 'favicon.ico' }
      expect(item['thumb']).to eq('/media/1/favicon.ico')
    end
  end
end
