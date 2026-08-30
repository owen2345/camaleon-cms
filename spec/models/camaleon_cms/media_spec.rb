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

    it 'does not destroy sibling rows when a degenerate root folder is removed' do
      junk = site.public_media.create!(name: '/', folder_path: '/', is_folder: true)
      sibling_folder = site.public_media.create!(name: 'docs', folder_path: '/', is_folder: true)
      sibling_file = site.public_media.create!(name: 'a.txt', folder_path: '/', is_folder: false)
      nested = site.public_media.create!(name: 'b.txt', folder_path: '/docs', is_folder: false)

      junk.destroy!

      expect(described_class.exists?(sibling_folder.id)).to be true
      expect(described_class.exists?(sibling_file.id)).to be true
      expect(described_class.exists?(nested.id)).to be true
    end

    it 'destroys mutually-aliasing degenerate rows without recursing or wiping siblings' do
      row_a = site.public_media.create!(name: '/', folder_path: '/', is_folder: true)
      row_b = site.public_media.create!(name: './', folder_path: '/', is_folder: true)
      sibling = site.public_media.create!(name: 'keep.txt', folder_path: '/', is_folder: false)

      expect { row_a.destroy! }.not_to raise_error
      expect { row_b.destroy! }.not_to raise_error
      expect(described_class.exists?(sibling.id)).to be true
    end

    it 'destroys a cross-path aliasing pair without recursing' do
      row_a = site.public_media.create!(name: '..', folder_path: '/.', is_folder: true)
      row_b = site.public_media.create!(name: '.', folder_path: '/..', is_folder: true)

      expect { row_a.destroy! }.not_to raise_error
      expect { row_b.destroy! }.not_to raise_error
    end
  end

  describe '#items' do
    it 'excludes the folder itself even when loaded without its id column' do
      folder = site.public_media.create!(name: '.', folder_path: '/.', is_folder: true)

      partial = site.public_media.select(:name, :folder_path, :is_public, :is_folder, :site_id)
                    .find_by(name: '.', folder_path: '/.')

      expect(partial.id).to be_nil
      expect(partial.items.to_a).not_to include(folder)
    end
  end
end
