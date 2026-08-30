# frozen_string_literal: true

RSpec.describe CamaleonCms::Media, type: :model do
  let(:site) { Cama::Site.first }

  # Persist a row the canonical-position validation would now reject, to simulate
  # the pre-validation (legacy / externally-written) data the destroy and listing
  # guards must still handle.
  def persist_legacy(attrs)
    record = site.public_media.new(attrs)
    record.save!(validate: false)
    record
  end

  describe '#destroy' do
    it 'destroys a folder whose items path resolves to its own path without recursing' do
      folder = persist_legacy(name: '.', folder_path: '/.', is_folder: true)

      expect { folder.destroy! }.not_to raise_error
      expect(described_class.exists?(folder.id)).to be false
    end

    it 'destroys a root folder whose name collapses to the root path without recursing' do
      folder = persist_legacy(name: '/', folder_path: '/', is_folder: true)

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
      junk = persist_legacy(name: '/', folder_path: '/', is_folder: true)
      sibling_folder = site.public_media.create!(name: 'docs', folder_path: '/', is_folder: true)
      sibling_file = site.public_media.create!(name: 'a.txt', folder_path: '/', is_folder: false)
      nested = site.public_media.create!(name: 'b.txt', folder_path: '/docs', is_folder: false)

      junk.destroy!

      expect(described_class.exists?(sibling_folder.id)).to be true
      expect(described_class.exists?(sibling_file.id)).to be true
      expect(described_class.exists?(nested.id)).to be true
    end

    it 'destroys mutually-aliasing degenerate rows without recursing or wiping siblings' do
      row_a = persist_legacy(name: '/', folder_path: '/', is_folder: true)
      row_b = persist_legacy(name: './', folder_path: '/', is_folder: true)
      sibling = site.public_media.create!(name: 'keep.txt', folder_path: '/', is_folder: false)

      expect { row_a.destroy! }.not_to raise_error
      expect { row_b.destroy! }.not_to raise_error
      expect(described_class.exists?(sibling.id)).to be true
    end

    it 'destroys a cross-path aliasing pair without recursing' do
      row_a = persist_legacy(name: '..', folder_path: '/.', is_folder: true)
      row_b = persist_legacy(name: '.', folder_path: '/..', is_folder: true)

      expect { row_a.destroy! }.not_to raise_error
      expect { row_b.destroy! }.not_to raise_error
    end
  end

  describe '#items' do
    it 'excludes the folder itself even when loaded without its id column' do
      folder = persist_legacy(name: '.', folder_path: '/.', is_folder: true)

      partial = site.public_media.select(:name, :folder_path, :is_public, :is_folder, :site_id)
                    .find_by(name: '.', folder_path: '/.')

      expect(partial.id).to be_nil
      expect(partial.items.to_a).not_to include(folder)
    end
  end

  describe '#delete_folder_items' do
    it 'does not destroy real rows when an unsaved folder instance is destroyed' do
      child = site.public_media.create!(name: 'real.txt', folder_path: '/docs', is_folder: false)

      site.public_media.new(name: 'docs', folder_path: '/', is_folder: true).destroy

      expect(described_class.exists?(child.id)).to be true
    end
  end

  describe '#create_parent_folders' do
    it 'does not mint blank-name folder rows from doubled slashes in the path' do
      record = site.public_media.new(name: 'b', folder_path: '/a//b', is_folder: true)

      record.send(:create_parent_folders)

      expect(site.public_media.where(name: '').exists?).to be false
      expect(site.public_media.exists?(name: 'a', folder_path: '/')).to be true
    end
  end

  describe 'a folder row without a site' do
    it 'can be saved and destroyed without raising' do
      orphan = described_class.new(name: 'orphan', folder_path: '/', is_folder: true, site: nil)

      expect { orphan.save! }.not_to raise_error
      expect { orphan.destroy! }.not_to raise_error
    end
  end

  describe 'is_public validation' do
    it 'rejects a NULL is_public' do
      expect do
        site.public_media.create!(name: 'x', folder_path: '/', is_folder: true, is_public: nil)
      end.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'accepts explicit true and false' do
      expect(site.public_media.new(name: 'pub', folder_path: '/', is_folder: true, is_public: true)).to be_valid
      expect(site.public_media.new(name: 'priv', folder_path: '/', is_folder: true, is_public: false)).to be_valid
    end
  end

  describe 'canonical position validation' do
    it 'rejects a name that collapses under the media key' do
      expect(site.public_media.new(name: '.', folder_path: '/', is_folder: true)).to be_invalid
      expect(site.public_media.new(name: '..', folder_path: '/', is_folder: true)).to be_invalid
      expect(site.public_media.new(name: '/', folder_path: '/', is_folder: true)).to be_invalid
    end

    it 'rejects a name containing a path separator that aliases another folder' do
      expect(site.public_media.new(name: 'b/', folder_path: '/a', is_folder: true)).to be_invalid
    end

    it 'rejects a non-canonical folder_path' do
      expect(site.public_media.new(name: 'x', folder_path: '/a//b', is_folder: false)).to be_invalid
      expect(site.public_media.new(name: 'x', folder_path: '/.', is_folder: false)).to be_invalid
      expect(site.public_media.new(name: 'x', folder_path: '/a/', is_folder: false)).to be_invalid
    end

    it 'accepts normal folders and files' do
      expect(site.public_media.new(name: 'docs', folder_path: '/', is_folder: true)).to be_valid
      expect(site.public_media.new(name: 'a.txt', folder_path: '/docs', is_folder: false)).to be_valid
      expect(site.public_media.new(name: 'file.tar.gz', folder_path: '/a/b', is_folder: false)).to be_valid
    end
  end
end
