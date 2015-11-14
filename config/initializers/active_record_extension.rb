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
  # sample: CamaleonCms::Site.first.posts.sort_by_field("untitled-field-attributes", "desc")
  def sort_by_field(key, order = "ASC")
    # class_name = self.build.class.name
    # table_name = class_name.classify.table_name
    self.includes(:custom_field_values).where("#{CamaleonCms::CustomFieldsRelationship.table_name}.custom_field_slug = ? and #{CamaleonCms::CustomFieldsRelationship.table_name}.object_class = ?", key, self.build.class.name).reorder("#{CamaleonCms::CustomFieldsRelationship.table_name}.value #{order}")
  end

  # Filter by custom field values
  # Arguments:
  # key: (String) Custom field key
  # sample: my_posts_that_include_my_field = CamaleonCms::Site.first.posts.filter_by_field("untitled-field-attributes")
  #   this will return all posts of the first site that include custom field "untitled-field-attributes"
  #   additionally, you can add extra filter: my_posts_that_include_my_field.where("#{CamaleonCms::CustomFieldsRelationship.table_name}.value=?", "my_value_for_field")
  def filter_by_field(key)
    self.includes(:custom_field_values).where("#{CamaleonCms::CustomFieldsRelationship.table_name}.custom_field_slug = ? and #{CamaleonCms::CustomFieldsRelationship.table_name}.object_class = ?", key, self.build.class.name)
  end
end


# add cache_var for models
ActiveRecord::Base.class_eval do
  # save cache value for this key
  def cama_set_cache(key, val)
    @cama_cache_vars ||= {}
    @cama_cache_vars[cama_build_cache_key(key)] = val
    val
  end

  # remove cache value for this key
  def cama_remove_cache(key)
    @cama_cache_vars.delete(cama_build_cache_key(key))
  end

  # fetch the cache value for this key
  def cama_fetch_cache(key)
    @cama_cache_vars ||= {}
    _key = cama_build_cache_key(key)
    if @cama_cache_vars.has_key?(_key)
      # puts "*********** using model cache var: #{_key}"
      @cama_cache_vars[_key]
    else
      @cama_cache_vars[_key] = yield
      @cama_cache_vars[_key]
    end
  end

  # return the cache value for this key
  def cama_get_cache(key)
    @cama_cache_vars ||= {}
    @cama_cache_vars[cama_build_cache_key(key)] rescue nil
  end

  # internal helper to generate cache key
  def cama_build_cache_key(key)
    _key = "cama_cache_#{self.class.name}_#{self.id}_#{key}"
  end
end