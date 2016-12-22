class CamaleonCms::Widget::Main < CamaleonCms::TermTaxonomy
  default_scope { where(taxonomy: :widget) }
  # attr_accessible :excerpt, :renderer
  # name: "title"
  # description: "content for this"
  # slug: "key for this"
  # status = simple or complex (default)
  # excerpt: string for message
  # renderer: string (path to the template for render this widget)

  has_many :metas, ->{ where(object_class: 'Widget::Main')}, :class_name => "CamaleonCms::Meta", foreign_key: :objectid, dependent: :destroy
  belongs_to :owner, class_name: PluginRoutes.static_system_info['user_model'].presence || 'CamaleonCms::User', foreign_key: :user_id
  belongs_to :site, :class_name => "CamaleonCms::Site", foreign_key: :parent_id

  has_many :assigned, class_name: "CamaleonCms::Widget::Assigned", foreign_key: :visibility, dependent: :destroy
  before_save :check_excerpt
  def is_simple?
    self.status == "simple"
  end

  def excerpt=(value)
    @excerpt = value
  end
  def excerpt
    self.get_option("excerpt")
  end

  def renderer=(value)
    @renderer = value
  end
  def renderer
    self.get_option("renderer")
  end

  def short_code
    "[widget #{self.slug}]"
  end

  private
  def check_excerpt
    self.set_option("excerpt", @excerpt)
    self.set_option("renderer", @renderer)
  end
end
