class CamaleonCms::NavMenu < CamaleonCms::TermTaxonomy
  default_scope { where(taxonomy: :nav_menu).order(id: :asc) }
  alias_attribute :site_id, :parent_id
  has_many :metas, ->{ where(object_class: 'NavMenu')}, :class_name => "CamaleonCms::Meta", foreign_key: :objectid, dependent: :destroy
  has_many :children, class_name: "CamaleonCms::NavMenuItem", foreign_key: :parent_id, dependent: :destroy, inverse_of: :parent
  belongs_to :site, :class_name => "CamaleonCms::Site", foreign_key: :parent_id, inverse_of: :nav_menus

  # add menu item for current menu
  # value: (Hash) is a hash object that contains label, type, link
  #   options for type: post | category | post_type | post_tag | external
  # sample: {label: "my label", type: "external", link: "http://camaleon.tuzitio.com", target: '_blank'}
  # sample: {label: "my label", type: "post", link: 10}
  # sample: {label: "my label", type: "category", link: 12}
  # return item created
  def append_menu_item (value)
    item = children.create!({name: value[:label], url: value[:link], kind: value[:type], target: value[:target]})
    item
  end

  # skip uniq slug validation
  def skip_slug_validation?
    true
  end

  private
  # overwrite termtaxonomy method
  def destroy_dependencies
  end
end
