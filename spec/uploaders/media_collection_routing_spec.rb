# frozen_string_literal: true

# Guards the is_public integrity fix: the uploader mode must route to the collection whose
# is_public value matches the file's real visibility, so the stored flag (and the public_media /
# private_media associations) mean what they say. On master these expectations fail — the private
# mode resolved to public_media and vice versa, storing is_public inverted.
RSpec.describe 'media collection routing (is_public integrity)' do # rubocop:disable RSpec/DescribeClass
  init_site

  let(:site) { Cama::Site.first.decorate }
  let(:private_uploader) { CamaleonCmsUploader.new(current_site: site, private: true) }
  let(:public_uploader) { CamaleonCmsUploader.new(current_site: site) }

  # Persist a file through the uploader's own collection (the write path under test) and return the
  # stored row.
  def cache_file(uploader, name)
    uploader.cache_item('name' => name, 'folder_path' => '/', 'is_folder' => false,
                        'file_type' => 'image', 'url' => "/media/1/#{name}", 'thumb' => '')
    uploader.send(:get_media_collection).find_by(name: name, folder_path: '/')
  end

  describe '#get_media_collection maps mode to the matching-visibility collection' do
    it 'routes a private uploader to private_media (is_public: false)' do
      expect(private_uploader.send(:get_media_collection).new.is_public).to be false
    end

    it 'routes a public uploader to public_media (is_public: true)' do
      expect(public_uploader.send(:get_media_collection).new.is_public).to be true
    end
  end

  describe 'stored is_public reflects real visibility' do
    it 'persists a privately uploaded file as is_public: false' do
      row = cache_file(private_uploader, 'secret.pdf')

      expect(row.is_public).to be false
      expect(site.private_media.where(name: 'secret.pdf', folder_path: '/')).to exist
      expect(site.public_media.where(name: 'secret.pdf', folder_path: '/')).not_to exist
    end

    it 'persists a publicly uploaded file as is_public: true' do
      row = cache_file(public_uploader, 'logo.png')

      expect(row.is_public).to be true
      expect(site.public_media.where(name: 'logo.png', folder_path: '/')).to exist
      expect(site.private_media.where(name: 'logo.png', folder_path: '/')).not_to exist
    end
  end

  describe 'visibility associations return the collection their name denotes' do
    it 'keeps public and private files in their own association' do
      cache_file(public_uploader, 'logo.png')
      cache_file(private_uploader, 'secret.pdf')

      public_names = site.public_media.where(folder_path: '/').pluck(:name)
      private_names = site.private_media.where(folder_path: '/').pluck(:name)

      expect(public_names).to include('logo.png')
      expect(public_names).not_to include('secret.pdf')
      expect(private_names).to include('secret.pdf')
      expect(private_names).not_to include('logo.png')
    end
  end
end
