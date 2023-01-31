# frozen_string_literal: true

class AddStiClassToPosts < CamaManager.migration_class
  def change
    add_column CamaleonCms::PostDefault.table_name, :type, :string, index: true
  end
end
