# frozen_string_literal: true

require 'memoist'
module CamaleonCms::Metas
  extend ActiveSupport::Concern
  extend Memoist
  included do
    attr_accessor :data_options
    attr_accessor :data_metas
    after_save  :save_metas_options
    has_many :metas, as: :record, dependent: :delete_all
    has_one :options_meta, -> { where(key: '_default') }, as: :record, class_name: 'Meta'
  end

  # Add meta with value or Update meta with key: key
  # return true or false
  def set_meta(key, value)
    metas.where(key: key).update_or_create(value: CamaleonCms::Meta.parse_value(value))
  end

  # return value of meta with key: key,
  # if meta not exist, return default
  # return default if meta value == ""
  def get_meta(key, default = nil)
    meta = metas.find_by(key: key)
    value = meta&.value || default
    value = JSON.parse(value) rescue value
    value.is_a?(Hash) ? value.with_indifferent_access : value
  end
  memoize :get_meta

  # delete meta
  def delete_meta(key)
    metas.where(key: key).destroy_all
  end

  # @return [Hash] option values for current model
  def options(_meta_key = "_default")
    JSON.parse(options_meta&.value || '{}')&.with_indifferent_access rescue option.value
  end
  alias_method :cama_options, :options
  memoize :options

  # @param data [Hash] options data
  # @param replace [Boolean] if true, will override all options with data
  def set_options(data, replace: false)
    data = PluginRoutes.fixActionParameter(data || {})
    data = options.merge(data) unless replace
    (options_meta || build_options_meta).update!(value: data.to_json)
  end
  alias_method :set_multiple_options, :set_options

  # add configuration for current object
  # key: attribute name
  # value: attribute value
  # meta_key: (String) name of the meta attribute
  # sample: mymodel.set_custom_option("my_settings", "color", "red")
  def set_option(key, value = nil, _meta_key = "_default")
    set_options({ key.to_s => value }) if key
    value
  end

  # return configuration for current object
  # key: attribute name
  # default: if attribute not exist, return default
  # return default if option value == ""
  # return value for attribute
  def get_option(key, default = nil, _meta_key = "_default")
    key = key.to_s
    options.has_key?(key) && options[key] != "" ? options[key] : default
  end
  memoize :get_option

  # delete attribute from configuration
  def delete_option(key, _meta_key = "_default")
    set_options(options.except(key.to_s), replace: true)
  end

  # save multiple metas
  # sample: set_metas({name: 'Owen', email: 'owenperedo@gmail.com'})
  def set_metas(data_metas)
    (data_metas || {}).each { |key, value| set_meta(key, value) }
  end

  private

  def save_metas_options
    set_options(data_options) if data_options
    set_metas(data_metas) if data_metas
  end
end
