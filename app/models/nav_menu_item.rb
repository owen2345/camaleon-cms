class NavMenuItem < TermTaxonomy
  default_scope { where(taxonomy: :nav_menu_item) }
  has_many :metas, ->{ where(object_class: 'NavMenuItem')}, :class_name => "Meta", foreign_key: :objectid, dependent: :destroy
  belongs_to :parent, class_name: "NavMenu"
  belongs_to :parent_item, class_name: "NavMenuItem", foreign_key: :parent_id
  has_many :children, class_name: "NavMenuItem", foreign_key: :parent_id, dependent: :destroy

  after_create :update_count
  #before_destroy :update_count

  # return the type of this menu (post|category|post_tag|post_type|external)
  def get_type
    self.get_option('type')
  end

  # check if this menu have children
  def have_children?
    self.children.count != 0
  end

  private
  def update_count
    self.parent.update_column('count', self.parent.children.size) if self.parent.present?
    self.parent_item.update_column('count', self.parent_item.children.size) if self.parent_item.present?
  end


end
