class ImproveMenusStructure < ActiveRecord::Migration
  def change
    CamaleonCms::NavMenuItem.all.each do |menu|
      menu.update_columns({description: menu.get_option('object_id'), slug: menu.get_option('type')})
    end
  end
end
