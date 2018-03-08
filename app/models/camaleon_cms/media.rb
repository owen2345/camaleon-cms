class CamaleonCms::Media < ActiveRecord::Base
  self.table_name = "#{PluginRoutes.static_system_info['db_prefix']}media"

  validates :name, uniqueness: {
    scope: [:site_id, :is_folder, :folder_path],
    message: 'Duplicates not allowed'
  }

  default_scope { order(:name) }

  def self.search(search_expression = '', folder = nil)
    if search_expression.blank?
      where(folder_path: folder)
    else
      where('name like ?', "%#{search_expression}%")
    end
  end
end
