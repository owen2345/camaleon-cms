class CamaleonCms::Plugin < CamaleonCms::TermTaxonomy
  # attrs:
  #   term_group => status active (1, nil)
  #   slug => plugin key
  #   name => plugin name

  attr_accessor :error

  has_many :metas, -> { where(object_class: 'Plugin') }, class_name: "CamaleonCms::Meta", foreign_key: :objectid, dependent: :destroy
  belongs_to :site, class_name: "CamaleonCms::Site", foreign_key: :parent_id

  default_scope { where(taxonomy: :plugin) }
  scope :active, -> { where(term_group: 1) }

  before_validation :set_default
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

  # check if current installation version is older
  # return boolean
  def old_version?
    # self.installed_version.to_s != self.settings["version"].to_s
    false
  end

  # set a new installation version for this plugin
  def installed_version=(version)
    self.set_option("version_installed", version)
  end

  # return gem installed version
  def installed_version
    return ""
    res = self.get_option("version_installed")
    unless res.present? # fix for old installations
      res = self.settings["version"]
      self.installed_version= res
    end
    res
  end

  # return the title of this plugin
  def title
    PluginRoutes.plugin_info(self.slug)["title"]
  end

  private
  def set_default
    self.name = self.slug unless self.name.present?
  end

  def destroy_custom_fields
    self.get_field_groups.destroy_all
  end

end
