module CamaleonCms::Metas extend ActiveSupport::Concern
  included do
    # options and metas auto save support
    attr_accessor :data_options
    attr_accessor :data_metas
    after_create  :save_metas_options, unless: :save_metas_options_skip
    before_update :fix_save_metas_options_no_changed

    has_many :metas, ->(object){ where(object_class: object.class.to_s.gsub("Decorator","").gsub("CamaleonCms::", "")) }, class_name: "CamaleonCms::Meta", foreign_key: :objectid, dependent: :delete_all
  end

  # Add meta with value or Update meta with key: key
  # return true or false
  def set_meta(key, value)
    metas.where(key: key).update_or_create({value: fix_meta_value(value)})
    cama_set_cache("meta_#{key}", value)
  end

  # return value of meta with key: key,
  # if meta not exist, return default
  # return default if meta value == ""
  def get_meta(key, default = nil)
    key_str = key.is_a?(Symbol) ? key.to_s : key
    cama_fetch_cache("meta_#{key_str}") do
      option = metas.loaded? ? metas.select{|m| m.key == key }.first : metas.where(key: key_str).first
      res = ''
      if option.present?
        value = JSON.parse(option.value) rescue option.value
        res = (value.is_a?(Hash) ? value.with_indifferent_access : value) rescue option.value
      end
      res == '' ? default : res
    end
  end

  # delete meta
  def delete_meta(key)
    metas.where(key: key).destroy_all
    cama_remove_cache("meta_#{key}")
  end

  # return configurations for current object, sample: {"type":"post_type","object_id":"127"}
  def options(meta_key = "_default")
    get_meta(meta_key, {})
  end
  alias_method :cama_options, :options

  # add configuration for current object
  # key: attribute name
  # value: attribute value
  # meta_key: (String) name of the meta attribute
  # sample: mymodel.set_custom_option("my_settings", "color", "red")
  def set_option(key, value = nil, meta_key = "_default")
    return if key.nil?
    data = cama_options(meta_key)
    data[key] = fix_meta_var(value)
    set_meta(meta_key, data)
    value
  end

  # return configuration for current object
  # key: attribute name
  # default: if attribute not exist, return default
  # return default if option value == ""
  # return value for attribute
  def get_option(key = nil, default = nil, meta_key = "_default")
    values = cama_options(meta_key)
    key = key.to_sym
    values.has_key?(key) && values[key] != "" ? values[key] : default
  end

  # delete attribute from configuration
  def delete_option(key, meta_key = "_default")
    values = cama_options(meta_key)
    key = key.to_sym
    values.delete(key) if values.has_key?(key)
    set_meta(meta_key, values)
  end

  # set multiple configurations
  # h: {ket1: "sdsds", ff: "fdfdfdfd"}
  def set_options(h = {}, meta_key = "_default")
    if h.present?
      data = cama_options(meta_key)
      PluginRoutes.fixActionParameter(h).to_sym.each do |key, value|
        data[key] = fix_meta_var(value)
      end
      set_meta(meta_key, data)
    end
  end
  alias_method :set_multiple_options, :set_options

  # save multiple metas
  # sample: set_metas({name: 'Owen', email: 'owenperedo@gmail.com'})
  def set_metas(data_metas)
    (data_metas.nil? ? {} : data_metas).each do |key, value|
      self.set_meta(key, value)
    end
  end

  # permit to skip save_metas_options in specific models
  def save_metas_options_skip
    false
  end

  # fix to save options and metas when a model was not changed
  def fix_save_metas_options_no_changed
    save_metas_options #unless self.changed?
  end

  # save all settings for this post type received in data_options and data_metas attribute (options and metas)
  # sample: Site.first.post_types.create({name: "owen", slug: "my_post_type", data_options: { has_category: true, default_layout: "my_layout" }})
  def save_metas_options
    set_multiple_options(data_options)
    if data_metas.present?
      data_metas.each do |key, val|
        set_meta(key, val)
      end
    end
  end

  private
  # fix to parse value
  def fix_meta_value(value)
    if (value.is_a?(Array) || value.is_a?(Hash) || value.is_a?(ActionController::Parameters))
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
