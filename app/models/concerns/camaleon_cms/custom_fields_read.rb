# frozen_string_literal: true

require 'memoist'
# The following methods exist only for backward compatibility
module CamaleonCms::CustomFieldsRead
  extend ActiveSupport::Concern
  extend Memoist

  included do
    attr_accessor :data_field_values
    after_save  :save_field_values
  end

  # get custom field groups for current object
  # only: Post_type, Post, Category, PostTag, Widget, Site and a Custom model pre configured
  # Sample: mypost.get_field_groups() ==> return fields for posts from parent posttype
  # Sample: mycat.get_field_groups() ==> return fields for categories from parent posttype
  # Sample: myposttag.get_field_groups() ==> return fields for posttags from parent posttype
  # @return collections CustomFieldGroup
  def get_field_groups(kind = {})
    klass = self.class.name
    kind = kind[:kind] if kind.is_a?(Hash)
    if klass == 'CamaleonCms::PostType'
      if kind == 'all'
        field_groups
      elsif %w[post_type self].include?(kind) || kind.nil?
        self.self_field_groups
      else
        send(:"#{kind.downcase}_field_groups")
      end
    elsif klass == 'CamaleonCms::Site' || klass == 'CamaleonCms::Post'
      kind == 'self' ? self_field_groups : field_groups
    else
      field_groups
    end
  end

  # get custom field value
  # _key: custom field key
  # if value is not present, then return default
  # return default only if the field was not registered
  def get_field_value(_key, _default = nil, group_number = 0)
    v = get_field_values(_key, group_number).first rescue _default
    v.present? ? v : _default
  end
  alias_method :get_field, :get_field_value
  alias_method :get_field!, :get_field_value
  memoize :get_field_value

  # get custom field values
  # _key: custom field key
  def get_field_values(key, group_number = 0)
    field_values.ordered.where(field_slug: key, group_number: group_number).pluck(:value)
  end
  alias_method :get_fields, :get_field_values
  memoize :get_field_values

  # return the values of custom fields grouped by group_number
  # field_keys: (array of keys)
  # samples: my_object.get_fields_grouped(['my_slug1', 'my_slug2'])
  #   return: [
  #             { 'my_slug1' => ["val 1"], 'my_slug2' => ['val 2']},
  #             { 'my_slug1' => ["val2 for slug1"], 'my_slug2' => ['val 2 for slug2']}
  #   ] ==> 2 groups
  #
  #   return: [
  #             { 'my_slug1' => ["val 1", 'val 2 for fields multiple support'], 'my_slug2' => ['val 2']},
  #             { 'my_slug1' => ["val2 for slug1", 'val 2'], 'my_slug2' => ['val 2 for slug2']}
  #             { 'my_slug1' => ["val3 for slug1", 'val 3'], 'my_slug2' => ['val 3 for slug2']}
  #   ] ==> 3 groups
  #
  #   puts res[0]['my_slug1'].first ==> "val 1"
  def get_fields_grouped(field_keys)
    res = []
    field_values.where(field_slug: field_keys).group_order.group_by(&:group_number).each do |group_number, group_fields|
      group = {}
      field_keys.each do |field_key|
        _tmp = []
        group_fields.each{ |field| _tmp << field.value if field_key == field.field_slug }
        group[field_key] = _tmp if _tmp.present?
      end
      res << group
    end
    res
  end

  # return all values
  # {key1: "single value", key2: [multiple, values], key3: value4} if include_options = false
  # {key1: {values: "single value", options: {a:1, b: 4}}, key2: {values: [multiple, values], options: {a=1, b=2} }} if include_options = true
  # TODO: refactor me
  def get_field_values_hash(include_options = false)
    fields = {}
    field_values.eager_load(:field).to_a.uniq.each do |field_value|
      field = field_value.field
      values = field.field_values.where(record: self).pluck(:value)
      fields[field_value.field_slug] = field.cama_options[:multiple].to_s.to_bool ? values : values.first unless include_options
      fields[field_value.field_slug] = { values: field.cama_options[:multiple].to_s.to_bool ? values : values.first, options: field.cama_options, id: field.id } if include_options
    end
    fields.to_sym
  end

  # return all custom fields for current element
  # {my_field_slug: {options: {}, values: [], name: '', ...} }
  # deprecated f attribute
  def get_fields_object(_f=true)
    fields = {}
    field_values.eager_load(:field).to_a.uniq.each do |field_value|
      field = field_value.field
      values = field.values.where(record: self).pluck(:value)
      fields[field_value.field_slug] = field.attributes.merge(options: field.cama_options, values: field.cama_options[:multiple].to_s.to_bool ? values : values.first)
    end
    fields.to_sym
  end
  memoize :get_fields_object


  # add a custom field group for current model
  # @param data (Hash)
    # name: name for the group
    # slug: key for group (if slug = _default => this will never show title and description)
    # description: description for the group (optional)
    # is_repeat: (boolean, optional -> default false) indicate if group support multiple format (repeated values)
  def add_custom_field_group(data, kind = nil)
    get_field_groups(kind).create!(data)
  end
  alias_method :add_field_group, :add_custom_field_group

  def default_custom_field_group(kind = nil)
    get_field_groups(kind).where(slug: '_default').first ||
      add_custom_field_group(name: 'Default Field Group', slug: '_default')
  end
  memoize :default_custom_field_group

  # Add custom fields for a default group:
  # This will create a new group with slug=_default if it doesn't exist yet
  # more details in add_manual_field(item, options) from custom field groups
  def add_field(data, settings, kind = nil)
    default_custom_field_group(kind).fields.create!(data.merge(settings: settings))
  end
  alias_method :add_custom_field_to_default_group, :add_field

  # return field object for current model
  def get_field_object(slug)
    fields.where(slug: slug).take
  end
  memoize :get_field_object

  # @param groups [Array<Group, Group> | Hash<slug: :value>] An array of group of fields or a Hash of fields
  #   @option Group [Hash<slug: :value>]
  def set_field_values(groups, replace: true)
    groups = parse_form_field_values(groups)
    groups = [groups] unless groups.is_a?(Array)
    ActiveRecord::Base.transaction do
      field_values.delete_all if replace
      groups.each_with_index do |items, group_no|
        items.each do |field_key, value_data|
          set_field_value(field_key, value_data, { group_number: group_no, clear: false })
        end
      end
    end
  end

  # key: (string required) slug of the custom field
  # value: (array | string) if array will save multiple values
  # args:
  #   field_id: (integer optional) identifier of the custom field
  #   order: order or position of the field value
  #   group_number: number of the group (only for custom field group with is_repeat enabled)
  #   clear: (boolean, default true) if true, will remove previous values and set these values, if not will append values
  def set_field_value(key, value, args = {})
    args = { clear: true }.merge(args)
    items = field_values.where(field_slug: key, group_number: args[:group_number] || 0)
    items.delete_all if args[:clear]
    values = (value.is_a?(Array) ? value : [value])
    values.each.with_index(args[:order] || 0) do |val, index|
      item = items.where(position: index).first_or_initialize
      item.update!(value: CamaleonCms::Meta.parse_value(val), field_id: item.field_id || args[:field_id])
    end
  end

  private

  # convert { 'group_no' => { 'field_key1' => { 'values' => { '0' => 'en', '1' => 'de' } } }, ... } into
  #   [{ field_key1: ['en', 'de'] }, ...]
  def parse_form_field_values(groups)
    from_form = groups.respond_to?(:keys) && (Integer(groups.keys.first) rescue false)
    return groups unless from_form

    groups.sort.map do |_group_no, items|
      items.map do |field_key, value_data|
        [field_key, value_data[:values].is_a?(Hash) ? value_data[:values].values : value_data[:values]]
      end.to_h
    end
  end

  def save_field_values
    set_field_values(data_field_values) if data_field_values
  end
end
