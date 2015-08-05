=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class PostRelationship < ActiveRecord::Base
  self.table_name = "term_relationships"
  attr_accessible :objectid, :term_taxonomy_id, :term_order
  default_scope ->{ order(term_order: :asc) }

  belongs_to :post_type, :class_name => "PostType", foreign_key: :term_taxonomy_id, inverse_of: :post_relationships
  belongs_to :posts, ->{ order("posts.id DESC") }, :class_name => "Post", foreign_key: :objectid, inverse_of: :post_relationships, dependent: :destroy

  # callbacks
  after_create :update_count
  before_destroy :update_count

  private
  def update_count
    self.post_type.update_column('count', self.post_type.posts.size) if self.post_type.present?
  end

end
