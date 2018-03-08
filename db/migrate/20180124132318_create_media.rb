class CreateMedia < ActiveRecord::Migration[5.1]
  def change
    create_table "#{PluginRoutes.static_system_info["db_prefix"]}media" do |t|
      t.references :site, index: true
      t.string :name, index: true
      t.boolean :is_folder, index: true, default: false
      t.string :folder_path, index: true
      t.string :file_size
      t.string :file_type
      t.string :url

      t.timestamps
    end
  end
end
