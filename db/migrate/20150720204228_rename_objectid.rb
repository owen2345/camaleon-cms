class RenameObjectid < ActiveRecord::Migration
  def change
    rename_column :custom_fields, :objectId, :objectid
    rename_column :custom_fields_relationships, :objectId, :objectid
    rename_column :metas, :objectId, :objectid
    rename_column :term_relationships, :objectId, :objectid
  end
end
