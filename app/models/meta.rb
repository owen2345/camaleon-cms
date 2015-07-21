class Meta < ActiveRecord::Base
  self.table_name = "metas"
  include MetasSaved
  attr_accessible :objectid, :key, :value, :object_class
  #belongs_to :parent, :foreign_key => :objectid


end
