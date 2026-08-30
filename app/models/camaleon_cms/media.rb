module CamaleonCms
  class Media < CamaleonRecord
    self.table_name = "#{PluginRoutes.static_system_info['db_prefix']}media"

    belongs_to :site, optional: true
    validates :name, uniqueness: {
      scope: %i[site_id is_folder folder_path is_public],
      message: 'Duplicates not allowed'
    }
    scope :only_folder, -> { where(is_folder: true) }
    scope :only_file, -> { where(is_folder: false) }
    default_scope { order(is_folder: :asc, name: :asc) }

    before_save :create_parent_folders
    before_destroy :delete_folder_items

    def self.search(search_expression = '', folder = nil)
      if search_expression.blank?
        where(folder_path: folder)
      else
        where('name like ?', "%#{search_expression}%")
      end
    end

    # search file or folder by key
    def self.by_key(key)
      key = key.cama_fix_media_key
      if key == '/'
        where(folder_path: File.dirname(key))
      else
        where(folder_path: File.dirname(key), name: File.basename(key))
      end
    end

    # legacy public name (pre-rename callers); the media table has no `key` column, so
    # without the alias this falls through to Rails' dynamic finder and raises
    class << self
      alias find_by_key by_key
    end

    # return all items of current folder
    def items
      coll = is_public ? site.public_media : site.private_media
      children_path = "#{folder_path}/#{name}".cama_fix_media_key
      # A folder's children live strictly below its own path. A name that collapses
      # under cama_fix_media_key (e.g. '.', '/', '..') resolves children_path back to
      # this row's own folder_path or an ancestor, which would make the folder select
      # its own siblings: destroy would then wipe them, or two such rows would select
      # each other and recurse forever. Descend only into a genuine sub-path, which
      # also makes cycles impossible (path depth would have to strictly increase).
      prefix = folder_path == '/' ? '/' : "#{folder_path}/"
      return coll.none unless children_path != folder_path && children_path.start_with?(prefix)

      coll.where(folder_path: children_path)
    end

    private

    # recover folder or file format
    def create_parent_folders
      coll = is_public ? site.public_media : site.private_media
      _p = []
      folder_path.split('/').each do |f_name|
        # A blank segment (doubled or trailing slash in folder_path) is not a real
        # folder; creating a row for it would mint a nameless folder whose own
        # children path collapses back onto its parent.
        next if f_name.blank?

        _path = "/#{_p.join('/')}".cama_fix_media_key
        if "#{_path}/#{f_name}".cama_fix_media_key != '/'
          coll.only_folder.where(name: f_name,
                                 folder_path: _path).first_or_create
        end
        _p.push(f_name)
      end
    end

    # return all children items
    def delete_folder_items
      # Rails runs before_destroy on unsaved records too. Such an instance owns no
      # persisted children, so cascading would destroy real rows that merely share
      # its computed path; only a persisted folder has children to remove.
      items.destroy_all if is_folder && persisted?
    end
  end
end
