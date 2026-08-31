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

  # Production never constructs a private uploader: the media controller builds a public
  # Local/Aws uploader and switches it with enable_private_mode! per request. The routing
  # contract must hold across that transition, not just for uploaders born private.
  describe 'the enable_private_mode! transition (the production private path)' do
    let(:uploader) { CamaleonCmsLocalUploader.new({ current_site: site }, nil) }

    it 'routes to private_media after the switch and persists is_public: false' do
      uploader.enable_private_mode!

      row = cache_file(uploader, 'switched.pdf')

      expect(row.is_public).to be false
      expect(site.private_media.where(name: 'switched.pdf', folder_path: '/')).to exist
      expect(site.public_media.where(name: 'switched.pdf', folder_path: '/')).not_to exist
    end

    it 'routes back to public_media after disable_private_mode!' do
      uploader.enable_private_mode!
      uploader.disable_private_mode!

      row = cache_file(uploader, 'switched-back.png')

      expect(row.is_public).to be true
      expect(site.public_media.where(name: 'switched-back.png', folder_path: '/')).to exist
    end
  end
end
