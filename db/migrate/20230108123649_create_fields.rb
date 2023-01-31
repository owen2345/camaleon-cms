# frozen_string_literal: true

class CreateFields < CamaManager.migration_class
  def change
    create_table CamaleonCms::Field.table_name do |t|
      t.string :name
      t.text :description
      t.string :slug, index: true, null: false, unique: true
      t.integer :position, default: 0
      t.belongs_to :field_group, foreign_key: { to_table: CamaleonCms::FieldGroup.table_name }

      t.timestamps
    end
  end
end
