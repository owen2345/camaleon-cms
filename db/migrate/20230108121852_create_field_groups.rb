# frozen_string_literal: true

class CreateFieldGroups < CamaManager.migration_class
  def change
    create_table CamaleonCms::FieldGroup.table_name do |t|
      t.belongs_to :site, type: :integer, foreign_key: { to_table: Cama::Site.table_name }
      t.string :name
      t.text :description
      t.string :slug, index: true, null: false, unique: true
      t.integer :position, default: 0
      t.boolean :repeat, default: false
      t.references :record, polymorphic: true
      t.string :kind

      t.timestamps
    end
  end
end
