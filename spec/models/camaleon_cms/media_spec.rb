# frozen_string_literal: true

RSpec.describe CamaleonCms::Media, type: :model do
  let(:site) { Cama::Site.first }

  describe '#destroy' do
    it 'destroys a folder whose items path resolves to its own path without recursing' do
      folder = site.public_media.create!(name: '.', folder_path: '/.', is_folder: true)

      expect { folder.destroy! }.not_to raise_error
      expect(described_class.exists?(folder.id)).to be false
    end

    it 'destroys a root folder whose name collapses to the root path without recursing' do
      folder = site.public_media.create!(name: '/', folder_path: '/', is_folder: true)

      expect { folder.destroy! }.not_to raise_error
      expect(described_class.exists?(folder.id)).to be false
    end

    it 'still destroys the real children of a folder' do
      folder = site.public_media.create!(name: 'docs', folder_path: '/', is_folder: true)
      child = site.public_media.create!(name: 'file.txt', folder_path: '/docs', is_folder: false)

      folder.destroy!

      expect(described_class.exists?(child.id)).to be false
    end
  end
end
