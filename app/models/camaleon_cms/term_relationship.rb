=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class CamaleonCms::TermRelationship < ActiveRecord::Base
  self.table_name = "#{PluginRoutes.static_system_info["db_prefix"]}term_relationships"
  default_scope ->{ order(term_order: :asc) }

  belongs_to :term_taxonomies, :class_name => "CamaleonCms::TermTaxonomy", foreign_key: :term_taxonomy_id, inverse_of: :term_relationships
  belongs_to :objects, ->{ order("#{CamaleonCms::Post.table_name}.id DESC") }, :class_name => "CamaleonCms::Post", foreign_key: :objectid, inverse_of: :term_relationships

  # callbacks
  after_create :update_count
  before_destroy :update_count

  private
  # update counter of post published items
  # TODO verify counter
  def update_count
    self.term_taxonomies.update_column('count', self.term_taxonomies.posts.published.size) if self.term_taxonomies.present?
  end

end
