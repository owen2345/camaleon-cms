# frozen_string_literal: true

class AddTimestampMetas < CamaManager.migration_class
  def change
    change_table CamaleonCms::Meta.table_name do |t|
      t.timestamps
    end
  end
end
