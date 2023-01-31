class CreateFieldValues < CamaManager.migration_class
  def change
    create_table CamaleonCms::FieldValue.table_name do |t|
      t.string :field_slug
      t.text :value
      t.integer :position, default: 0
      t.integer :group_number, default: 0
      t.references :record, polymorphic: true
      t.belongs_to :field, null: true, foreign_key: { to_table: CamaleonCms::Field.table_name }

      t.timestamps
    end
    index_name = 'cama_slug_record_id_record_type_field_values'
    add_index CamaleonCms::FieldValue.table_name, %i[field_slug record_id record_type], name: index_name
  end
end
