=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class CamaleonCms::Theme < CamaleonCms::TermTaxonomy
  # attrs:
  #   slug => plugin key
  default_scope { where(taxonomy: :theme) }
  has_many :metas, ->{ where(object_class: 'Theme')}, :class_name => "CamaleonCms::Meta", foreign_key: :objectid, dependent: :destroy
  belongs_to :site, :class_name => "CamaleonCms::Site", foreign_key: :parent_id

  before_validation :fix_name
  before_destroy :destroy_custom_fields

  # return theme settings configured in config.json
  def settings
    PluginRoutes.theme_info(self.slug)
  end

  # return the path to the settings file for current theme
  def settings_file
    File.join(self.settings["path"], "views/admin/settings.html.erb").to_s
  end

  private
  def fix_name
    self.name = self.slug unless self.name.present?
  end

  def destroy_custom_fields
    self.get_field_groups().destroy_all
  end

end
