class CamaleonCms::NavMenuItem < CamaleonCms::TermTaxonomy
  alias_attribute :site_id, :term_group
  alias_attribute :label, :name
  alias_attribute :url, :description
  alias_attribute :kind, :slug
  alias_attribute :target, :status
  # attr_accessible :label, :url, :kind
  default_scope { where(taxonomy: :nav_menu_item).order(id: :asc) }
  has_many :metas, ->{ where(object_class: 'NavMenuItem')}, :class_name => "CamaleonCms::Meta", foreign_key: :objectid, dependent: :destroy
  belongs_to :parent, class_name: "CamaleonCms::NavMenu", inverse_of: :children
  belongs_to :parent_item, class_name: "CamaleonCms::NavMenuItem", foreign_key: :parent_id, inverse_of: :children
  has_many :children, class_name: "CamaleonCms::NavMenuItem", foreign_key: :parent_id, dependent: :destroy, inverse_of: :parent_item

  before_create :set_parent_site
  after_create :update_count
  #before_destroy :update_count

  # return the main menu
  def main_menu
    main_menu = self.parent
    return main_menu if main_menu.present?
    parent_menu = self.parent_item
    parent_menu.main_menu if parent_menu.present?
  end

  # check if this menu have children
  def have_children?
    self.children.count != 0
  end

  # add sub menu for a menu item
  # same values of NavMenu#append_menu_item
  # return item created
  def append_menu_item(value)
    children.create({name: value[:label], url: value[:link], kind: value[:type], target: value[:target]})
  end

  # update current menu
  # value: same as append_menu_item (label, link, target)
  def update_menu_item(value)
    self.update({name: value[:label], url: value[:link], target: value[:target]})
  end

  # overwrite skip uniq slug validation
  def skip_slug_validation?; true end
  def before_validating; end

  private
  def update_count
    self.parent.update_column('count', self.parent.children.size) if self.parent.present?
    self.parent_item.update_column('count', self.parent_item.children.size) if self.parent_item.present?
    self.update_column(:term_group, main_menu.parent_id)
    self.update_column(:term_order, CamaleonCms::NavMenuItem.where(parent_id: self.parent_id).count) # update position
  end

  # fast access from site to menu items
  def set_parent_site
    self.site_id = self.parent_item.site_id if self.parent_item.present?
    self.site_id = self.parent.site_id if self.parent.present?
  end

  # overwrite inherit method
  def destroy_dependencies; end
end
