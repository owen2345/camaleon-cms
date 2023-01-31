# frozen_string_literal: true

class AddStiClassToTaxonomy < CamaManager.migration_class
  def change
    add_column CamaleonCms::TermTaxonomy.table_name, :type, :string, index: true
  end
end
