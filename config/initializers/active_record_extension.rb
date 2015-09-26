=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
module ActiveRecordExtras
  module Relation
    extend ActiveSupport::Concern

    module ClassMethods
      def update_or_create(attributes = {})
        assign_or_new(attributes).save
      end

      def update_or_create!(attributes = {})
        assign_or_new(attributes).save!
      end

      def assign_or_new(attributes)
        obj = first || new
        obj.assign_attributes(attributes)
        obj
      end
    end
  end
end

ActiveRecord::Base.send :include, ActiveRecordExtras::Relation

ActiveRecord::Associations::CollectionProxy.class_eval do
  # order a collection by custom fields
  # Arguments:
  # key: (String) Custom field key
  # order: (String) order direction (ASC | DESC)
  # sample: Site.first.posts.sort_by_field("untitled-field-attributes", "desc")
  def sort_by_field(key, order = "ASC")
    # class_name = self.build.class.name
    # table_name = class_name.classify.table_name
    self.includes(:custom_field_values).where("#{CustomFieldsRelationship.table_name}.custom_field_slug = ? and #{CustomFieldsRelationship.table_name}.object_class = ?", key, self.build.class.name).reorder("#{CustomFieldsRelationship.table_name}.value #{order}")
  end
end
