=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
module CamaleonCms::Metas extend ActiveSupport::Concern
  included do
    has_many :metas, ->(object){where(object_class: object.class.to_s.gsub("Decorator","").gsub("CamaleonCms::", ""))}, :class_name => "CamaleonCms::Meta", foreign_key: :objectid, dependent: :destroy
  end

  # Add meta with value or Update meta with key: key
  # return true or false
  def set_meta(key, value)
    metas.where(key: key).update_or_create({value: fix_meta_value(value)})
    cama_set_cache(key, value)
  end

  # return value of meta with key: key,
  # if meta not exist, return default
  def get_meta(key, default = nil)
    cama_fetch_cache("meta_#{key}") do
      option = metas.where(key: key).first
      if option.present?
        value = JSON.parse(option.value) rescue option.value
        (value.is_a?(Hash) ? value.to_sym : value) rescue option.value
      else
        default
      end
    end
  end

  # delete meta
  def delete_meta(key)
    metas.where(key: key).destroy_all
    cama_remove_cache(key)
  end

  # return configurations for current object, sample: {"type":"post_type","object_id":"127"}
  def options
    get_meta("_default", {})
  end

  # add configuration for current object
  # key: attribute name
  # value: attribute value
  def set_option(key, value = nil)
    return if key.nil?
    data = options
    data[key] = fix_meta_var(value)
    set_meta('_default', data)
  end

  # return configuration for current object
  # key: attribute name
  # default: if attribute not exist, return default
  # return value for attribute
  def get_option(key = nil, default = nil)
    values = options.present? ? options : {}
    key = key.to_sym
    values.has_key?(key) ? values[key] : default
  end

  # delete attribute from configuration
  def delete_option(key)
    values = options
    key = key.to_sym
    values.delete(key) if values.has_key?(key)
    set_meta('_default', values)
  end

  # set multiple configurations
  # h: {ket1: "sdsds", ff: "fdfdfdfd"}
  def set_multiple_options(h = {})
    if h.present?
      data = options
      h.each do |key, value|
        data[key] = fix_meta_var(value)
      end
      set_meta('_default', data)
    end
  end

  private
  # fix to parse value
  def fix_meta_value(value)
    if (value.is_a?(Array) || value.is_a?(Hash))
      value = value.to_json
    end
    fix_meta_var(value)
  end

  # fix to detect type of the variable
  def fix_meta_var(value)
    if value.is_a?(String)
      value = value.to_var
    end
    value
  end

end