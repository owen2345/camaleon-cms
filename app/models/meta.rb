class Meta < ActiveRecord::Base
  self.table_name = "metas"
  include MetasSaved
  attr_accessible :objectId, :key, :value, :object_class
  #belongs_to :parent, :foreign_key => :objectId


end
