# frozen_string_literal: true

class MakePolymorphicMetas < CamaManager.migration_class
  def change
    add_reference CamaleonCms::Meta.table_name, :record, polymorphic: true
  end
end
