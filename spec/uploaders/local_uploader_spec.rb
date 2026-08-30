# frozen_string_literal: true

RSpec.describe CamaleonCmsLocalUploader do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  let(:uploader) { described_class.new(current_site: current_site) }

  describe '#delete_folder (path containment)' do
    around do |example|
      Dir.mktmpdir do |dir|
        uploader.instance_variable_set(:@root_folder, dir)
        example.run
      end
    end

    it 'refuses a key that resolves to the media root and keeps the files' do
      keep = File.join(uploader.instance_variable_get(:@root_folder), 'keep.txt')
      File.write(keep, 'data')

      result = uploader.delete_folder('/.')

      expect(result).to eq(error: 'Invalid folder path')
      expect(File.exist?(keep)).to be true
    end

    it 'still deletes a genuine subfolder' do
      sub = File.join(uploader.instance_variable_get(:@root_folder), 'docs')
      FileUtils.mkdir_p(sub)

      uploader.delete_folder('/docs')

      expect(Dir.exist?(sub)).to be false
    end
  end

  describe '#add_file (key normalization)' do
    let(:root_folder) { uploader.instance_variable_get(:@root_folder) }

    def upload(key)
      io = Tempfile.new(['src', '.txt'])
      io.write('data')
      io.rewind
      uploader.add_file(io, key, same_name: true)
    ensure
      io.close
    end

    after do
      FileUtils.rm_f(File.join(root_folder, 'x.txt'))
      FileUtils.rm_rf(File.join(root_folder, 'temporal'))
    end

    it 'stores a canonical folder_path for a dot-segment key' do
      expect(upload('/./x.txt')['folder_path']).to eq('/')
    end

    it 'forces a leading slash for a key without one' do
      expect(upload('temporal/x.txt')['folder_path']).to eq('/temporal')
    end
  end

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

  describe '#file_parse thumb naming for an uppercase .SVG source' do
    let(:root_folder) { uploader.instance_variable_get(:@root_folder) }

    before do
      FileUtils.mkdir_p(File.join(root_folder, 'thumb'))
      File.write(File.join(root_folder, 'logo.SVG'), '<svg xmlns="http://www.w3.org/2000/svg"/>')
      # The generated thumb is a JPEG regardless of the source extension's case; stage it so
      # file_parse's on-disk check confirms the computed name instead of falling back.
      File.write(File.join(root_folder, 'thumb', 'logo-svg.jpg'), 'x')
    end

    after do
      FileUtils.rm_f(File.join(root_folder, 'logo.SVG'))
      FileUtils.rm_rf(File.join(root_folder, 'thumb'))
    end

    it 'computes the .jpg thumb url (case-insensitive svg-to-jpg rename)' do
      expect(uploader.file_parse('/logo.SVG')['thumb']).to end_with('/thumb/logo-svg.jpg')
    end
  end

  describe '#objects (lazy relation for DB-level pagination)' do
    let(:collection) { uploader.send(:get_media_collection) }

    it 'returns a lazy ActiveRecord relation, not a materialized array' do
      collection.create!(name: 'a.jpg', folder_path: '/', is_folder: false,
                         file_type: 'image', url: '/media/1/a.jpg', thumb: '')

      res = uploader.objects('/')

      expect(res).to be_a(ActiveRecord::Relation)
      expect(res).to respond_to(:limit)
    end
  end

  describe '#cama_prepare_browser_page (legacy thumbnail fallback, applied to the rendered page)' do
    let(:root_folder) { uploader.instance_variable_get(:@root_folder) }
    let(:thumb_dir) { File.join(root_folder, 'thumb') }
    let(:collection) { uploader.send(:get_media_collection) }

    before { FileUtils.mkdir_p(thumb_dir) }
    after { FileUtils.rm_rf(thumb_dir) }

    def create_image_media(thumb)
      collection.create!(name: 'photo.jpg', folder_path: '/', is_folder: false,
                         file_type: 'image', url: '/media/1/photo.jpg', thumb: thumb)
    end

    def prepared(name)
      uploader.cama_prepare_browser_page(uploader.objects('/').to_a).find { |i| i['name'] == name }
    end

    it 'rewrites cached .jpg thumb urls to the on-disk legacy .png' do
      File.write(File.join(thumb_dir, 'photo-jpg.png'), 'x')
      create_image_media('/media/1/thumb/photo-jpg.jpg')

      expect(prepared('photo.jpg')['thumb']).to eq('/media/1/thumb/photo-jpg.png')
    end

    it 'keeps the cached thumb url when the matching file exists on disk' do
      File.write(File.join(thumb_dir, 'photo-jpg.jpg'), 'x')
      create_image_media('/media/1/thumb/photo-jpg.jpg')

      expect(prepared('photo.jpg')['thumb']).to eq('/media/1/thumb/photo-jpg.jpg')
    end

    it 'falls back to the original file url for a cached item with no thumbnail on disk (favicon)' do
      collection.create!(name: 'favicon.ico', folder_path: '/', is_folder: false,
                         file_type: 'image', url: '/media/1/favicon.ico',
                         thumb: '/media/1/thumb/favicon-ico.ico')

      expect(prepared('favicon.ico')['thumb']).to eq('/media/1/favicon.ico')
    end
  end

  describe '#cama_prepare_browser_page on the base uploader (no-op)' do
    it 'returns the items unchanged' do
      items = [{ 'name' => 'x', 'thumb' => '/computed.jpg' }]
      base = CamaleonCmsUploader.new(current_site: current_site)

      expect(base.cama_prepare_browser_page(items)).to eq(items)
    end
  end
end
