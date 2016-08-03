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
    self.joins("LEFT OUTER JOIN #{CamaleonCms::CustomFieldsRelationship.table_name} ON #{CamaleonCms::CustomFieldsRelationship.table_name}.objectid = #{self.build.class.table_name}.id").where("#{CamaleonCms::CustomFieldsRelationship.table_name}.custom_field_slug = ? and #{CamaleonCms::CustomFieldsRelationship.table_name}.object_class = ?", key, self.build.class.name.parseCamaClass).reorder("#{CamaleonCms::CustomFieldsRelationship.table_name}.value #{order}")
  end

  # Filter by custom field values
  # Arguments:
  # key: (String) Custom field key
  # sample: my_posts_that_include_my_field = CamaleonCms::Site.first.posts.filter_by_field("untitled-field-attributes")
  #   this will return all posts of the first site that include custom field "untitled-field-attributes"
  #   additionally, you can add extra filter: my_posts_that_include_my_field.where("#{CamaleonCms::CustomFieldsRelationship.table_name}.value=?", "my_value_for_field")
  def filter_by_field(key, args = {})
    res = self.joins("LEFT OUTER JOIN #{CamaleonCms::CustomFieldsRelationship.table_name} ON #{CamaleonCms::CustomFieldsRelationship.table_name}.objectid = #{self.build.class.table_name}.id").where("#{CamaleonCms::CustomFieldsRelationship.table_name}.custom_field_slug = ? and #{CamaleonCms::CustomFieldsRelationship.table_name}.object_class = ?", key, self.build.class.name.parseCamaClass)
    res = res.where("#{CamaleonCms::CustomFieldsRelationship.table_name}.value = ?", args[:value]) if args[:value]
    res
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