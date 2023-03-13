# frozen_string_literal: true

class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  def self.cama_define_common_relationships(key)
    has_many :metas, -> { where(object_class: key) },
             class_name: 'CamaleonCms::Meta', foreign_key: :objectid, dependent: :destroy

    has_many :custom_field_values, -> { where(object_class: key) },
             class_name: 'CamaleonCms::CustomFieldsRelationship', foreign_key: :objectid, dependent: :delete_all

    has_many :custom_fields, -> { where(object_class: key) },
             class_name: 'CamaleonCms::CustomField', foreign_key: :objectid

    # valid only for simple groups and not for complex like: posts, post, ... where the group is for individual or
    # children groups
    has_many :custom_field_groups, -> { where(object_class: key) },
             class_name: 'CamaleonCms::CustomFieldGroup', foreign_key: :objectid
  end

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
    if @cama_cache_vars.key?(_key)
      # puts "*********** using model cache var: #{_key}"
    else
      @cama_cache_vars[_key] = yield
    end
    @cama_cache_vars[_key]
  end

  # return the cache value for this key
  def cama_get_cache(key)
    @cama_cache_vars ||= {}
    begin
      @cama_cache_vars[cama_build_cache_key(key)]
    rescue StandardError
      nil
    end
  end

  # internal helper to generate cache key
  def cama_build_cache_key(key)
    _key = "cama_cache_#{self.class.name}_#{id}_#{key}"
  end
end
