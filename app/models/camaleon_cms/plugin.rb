class CamaleonCms::Plugin < CamaleonCms::TermTaxonomy
  # attrs:
  #   term_group => status active (1, nil)
  #   slug => plugin key
  #   name => plugin name

  attr_accessor :error

  default_scope { where(taxonomy: :plugin) }
  scope :active, -> { where(term_group: 1) }

  has_many :metas, -> { where(object_class: 'Plugin') }, class_name: 'CamaleonCms::Meta',
    foreign_key: :objectid, dependent: :destroy
  belongs_to :site, class_name: 'CamaleonCms::Site', foreign_key: :parent_id

  before_validation :set_default
  before_destroy :destroy_custom_fields

  # active the plugin
  def active
    term_group = 1
    save
  end

  # inactive the plugin
  def inactive
    term_group = nil
    save
  end

  # check if plugin is active
  def active?
    term_group.to_s == '1'
  end

  # return theme settings configured in config.json
  def settings
    PluginRoutes.plugin_info(slug)
  end

  # check if current installation version is older
  # return boolean
  def old_version?
    # self.installed_version.to_s != self.settings["version"].to_s
    false
  end

  # set a new installation version for this plugin
  def installed_version=(version)
    set_option('version_installed', version)
  end

  # return gem installed version
  def installed_version
    return ""
    res = get_option('version_installed')
    unless res.present? # fix for old installations
      res = settings['version']
      installed_version = res
    end
    res
  end

  # return the title of this plugin
  def title
    PluginRoutes.plugin_info(slug)['title']
  end

  private

  def set_default
    name = slug unless name.present?
  end

  def destroy_custom_fields
    get_field_groups.destroy_all
  end
end
