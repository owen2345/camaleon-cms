class Plugin < TermTaxonomy
  # attrs:
  #   term_group => status active (1, nil)
  #   slug => plugin key
  #   name => plugin name
  default_scope { where(taxonomy: :plugin) }
  has_many :metas, ->{ where(object_class: 'Plugin')}, :class_name => "Meta", foreign_key: :objectid, dependent: :destroy
  belongs_to :site, :class_name => "Site", foreign_key: :parent_id
  scope :active, ->{ where(term_group: 1) }
  before_validation :set_default
  attr_accessor :error
  before_destroy :destroy_custom_fields

  # active the plugin
  def active
    self.term_group = 1
    self.save
  end

  # inactive the plugin
  def inactive
    self.term_group = nil
    self.save
  end

  # check if plugin is active
  def active?
    self.term_group.to_s == "1"
  end

  # return theme settings configured in config.json
  def settings
    PluginRoutes.plugin_info(self.slug)
  end

  def title
    PluginRoutes.plugin_info(self.slug)["title"]
  end

  private
  def set_default
    self.name = self.slug unless self.name.present?
  end

  def destroy_custom_fields
    self.get_field_groups().destroy_all
  end

end
