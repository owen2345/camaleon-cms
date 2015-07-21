module Metas extend ActiveSupport::Concern
  included do
    has_many :metas, ->(object){where(object_class: object.class.to_s.gsub("Decorator",""))}, :class_name => "Meta", foreign_key: :objectid, dependent: :destroy
  end
  @meta_data = nil

  # return collect meta for current model: Post, PostType, Categories, PostTag Site, User, Custom Fields
  def meta
    after_finding_meta
    @meta_data
  end

  # Add meta with value or Update meta with key: key
  # return true or false
  def set_meta(key, value)
    metas.where(key: key).update_or_create({value: fix_meta_value(value)})
    after_finding_meta(true)
  end

  # return value of meta with key: key,
  # if meta not exist, return default
  def get_meta(key, default = nil)
    option = metas.where(key: key).first
    if option.present?
      value = JSON.parse(option.value) rescue option.value
      (value.is_a?(Hash) ? value.to_sym : value) rescue option.value
    else
      default
    end
  end
  # delete meta
  def delete_meta(key)
    option = metas.where(key: key).first
    option.destroy if option.present?
  end


  # return configurations for current object, sample: {"type":"post_type","object_id":"127"}
  def options
    after_finding_meta
    @meta_data[:_default] || {}
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

  # set multiple configuration
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

  # set multiple datas
  # a: [{key: "sdsds", value: "fdfdfdfd"}, {key: "other", value: "texts"}]
  # update: true => update data, false => create new data
  def set_meta_data(a, update = false)
    if a.present?
      data = update ? meta[:set_meta_data] : {}
      a.each do |row|
        data[row[:key]] = fix_meta_var(row[:value])
      end
      set_meta('_set_meta_data', data)
    end
  end
  # return meta data
  def meta_data
    meta[:_set_meta_data] || {}
  end

  private

  def after_finding_meta(reset = false)
    if @meta_data.nil? || reset
      options = {}
      if metas.count > 0
        metas.all.each do |item|
          options[item.key] = JSON.parse(item.value) rescue item.value
        end
      end
      @meta_data = options.to_sym
    end
  end

  def fix_meta_value(value)
    if (value.is_a?(Array) || value.is_a?(Hash))
      value = value.to_json
    end
    fix_meta_var(value)
  end
  def fix_meta_var(value)
    if value.is_a?(String)
      value = value.to_var
    end
    value
  end

end