class Theme < TermTaxonomy
  # attrs:
  #   slug => plugin key
  default_scope { where(taxonomy: :theme) }
  has_many :metas, ->{ where(object_class: 'Theme')}, :class_name => "Meta", foreign_key: :objectid, dependent: :destroy
  belongs_to :site, :class_name => "Site", foreign_key: :parent_id

  before_validation :fix_name
  before_destroy :destroy_custom_fields

  # return theme settings configured in config.json
  def settings
    PluginRoutes.theme_info(self.slug)
  end

  private
  def fix_name
    self.name = self.slug unless self.name.present?
  end

  def destroy_custom_fields
    self.get_field_groups().destroy_all
  end

end
