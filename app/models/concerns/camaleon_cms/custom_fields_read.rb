=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
module CamaleonCms::CustomFieldsRead extend ActiveSupport::Concern
  included do
    has_many :fields, ->(object){ where(:object_class => object.class.to_s.gsub("Decorator","").gsub("CamaleonCms::",""))} , :class_name => "CamaleonCms::CustomField" ,foreign_key: :objectid
    has_many :field_values, ->(object){where(object_class: object.class.to_s.gsub("Decorator","").gsub("CamaleonCms::",""))}, :class_name => "CamaleonCms::CustomFieldsRelationship", foreign_key: :objectid, dependent: :destroy
    has_many :custom_field_values, :class_name => "CamaleonCms::CustomFieldsRelationship", foreign_key: :objectid, dependent: :destroy
    before_destroy :_destroy_custom_field_groups
  end


  # get custom field groups for current object
  # only: Post_type, Post, Category, PostTag, Widget, Site and a Custom model pre configured
  # return collections CustomFieldGroup
  # args: (Hash)
    # kind: argument only for PostType Objects: (Post (Default) | Category | PostTag).
      # If kind = "post_type" this will return groups for all post_types
    # include_parent: (boolean, default false) Permit to recover groups from self + parent post_type (argument valid only for Post | PostTag | Category)
  # args: (String) => is a value for kind attribute
  def get_field_groups(args = {})
    args = args.is_a?(String) ?  {kind: args, include_parent: false } : {kind: "post", include_parent: false }.merge(args)
    class_name = self.class.to_s.gsub("Decorator","").gsub("CamaleonCms::","")
    case class_name
      when 'Category','Post','PostTag'
        if args[:include_parent]
           self.post_type.site.custom_field_groups.where("(objectid = ? AND object_class = ?) OR (objectid = ? AND object_class = ?)", self.id || -1, class_name, self.post_type.id, "PostType_#{class_name}")
        else
          self.post_type.site.custom_field_groups.where(objectid: self.id || -1, object_class: class_name)
        end
      when 'Widget::Main'
        self.site.custom_field_groups.where(object_class: class_name, objectid:  self.id)
      when 'Theme'
        self.site.custom_field_groups.where(object_class: class_name, objectid:  self.id)
      when 'Site'
        self.custom_field_groups.where(object_class: class_name)
      when 'NavMenuItem'
        # self.main_menu.custom_field_groups //verify this problem
        puts "get_field_groups - NavMenuItem: **************#{self.inspect}***** #{self.main_menu.inspect}"
        CamaleonCms::NavMenu.find(self.main_menu.id).get_field_groups
      when 'PostType'
        if args[:kind] == "all"
          self.site.custom_field_groups.where(object_class: ["PostType_Post", "PostType_Post", "PostType_PostTag", "PostType"], objectid:  self.id )
        elsif args[:kind] == "post_type"
          self.site.custom_field_groups.where(object_class: class_name)
        else
          self.site.custom_field_groups.where(object_class: "PostType_#{args[:kind]}", objectid:  self.id )
        end
      else # 'Plugin' or other class
        self.site.custom_field_groups.where(object_class: class_name, objectid:  self.id) if defined?(self.site)
    end
  end

  # get custom field groups for current user
  # return collections CustomFieldGroup
  # site: site object
  def get_user_field_groups(site)
    class_name = self.class.to_s.gsub("Decorator","")
    site.custom_field_groups.where(object_class: class_name)
  end


  # get custom field value
  # _key: custom field key
  # if value is not present, then return default
  # return default only if the field was not registered
  def get_field_value(_key, _default = nil)
    v = _default
    v = get_field_values(_key).first rescue _default
    v.present? ? v : _default
  end
  alias_method :get_field, :get_field_value

  # the same as the_field() but if the value is not present, this will return default value
  def get_field!(_key, _default = nil)
    v = _default
    v = get_field_values(_key).first rescue _default
    v.present? ? v : _default
  end

  # get custom field values
  # _key: custom field key
  def get_field_values(_key)
    self.field_values.where(custom_field_slug: _key).pluck(:value)
  end
  alias_method :get_fields, :get_field_values

  # ------------- new function update field value -------------
  def update_field_value(_key, value = nil)
    self.field_values.where(custom_field_slug: _key).first.update_column('value', value) rescue nil
  end


  # return all values
  # {key1: "single value", key2: [multiple, values], key3: value4} if include_options = false
  # {key1: {values: "single value", options: {a:1, b: 4}}, key2: {values: [multiple, values], options: {a=1, b=2} }} if include_options = true
  def get_field_values_hash(include_options = false)
    fields = {}
    self.field_values.to_a.uniq.each do |field_value|
      custom_field = field_value.custom_fields
      values = custom_field.values.where(objectid: self.id).pluck(:value)
      fields[field_value.custom_field_slug] = custom_field.options[:multiple].to_s.to_bool ? values : values.first unless include_options
      fields[field_value.custom_field_slug] = {values: custom_field.options[:multiple].to_s.to_bool ? values : values.first, options: custom_field.options, id: custom_field.id} if include_options
    end
    fields.to_sym
  end

  # return all custom fields for current element
  # {my_field_slug: {options: {}, values: [], name: '', ...} }
  # deprecated f attribute
  def get_fields_object(f=true)
    fields = {}
    self.field_values.to_a.uniq.each do |field_value|
      custom_field = field_value.custom_fields
      # if custom_field.options[:show_frontend].to_s.to_bool
      values = custom_field.values.where(objectid: self.id).pluck(:value)
      fields[field_value.custom_field_slug] = custom_field.attributes.merge(options: custom_field.options, values: custom_field.options[:multiple].to_s.to_bool ? values : values.first)
      # end
    end
    fields.to_sym
  end


  # add a custom field group for current model
  # values:
    # name: name for the group
    # slug: key for group (if slug = _default => this will never show title and description)
    # description: description for the group (optional)
  # Model supported: PostType, Category, Post, Posttag, Widget, Plugin, Theme, User and Custom models pre configured
  # Note 1: If you need add fields for all post's or all categories, then you need to add the fields into the
  #     post_type.add_custom_field_group(values, kind = "Post")
  #     post_type.add_custom_field_group(values, kind = "Category")
  # Note 2: If you need add fields for only the Post_type, you have to use options or metas
  # return: CustomFieldGroup object
  # kind: argument only for PostType model: (Post | Category | PostTag), default => Post. If kind = "" this will add group for all post_types
  def add_custom_field_group(values, kind = "Post")
    values = values.with_indifferent_access
    group = get_field_groups(kind).where(slug: values[:slug]).first
    unless group.present?
      group = get_field_groups(kind).create(values)
    end
    group
  end
  alias_method :add_field_group, :add_custom_field_group

  # Add custom fields for a default group:
  # This will create a new group with slug=_default if it doesn't exist yet
  # more details in add_manual_field(item, options) from custom field groups
  # kind: argument only for PostType model: (Post | Category | PostTag), default => Post
  def add_custom_field_to_default_group(item, options, kind = "Post")
    g = get_field_groups(kind).where(slug: "_default").first
    g = add_custom_field_group({name: "Default Field Group", slug: "_default"}, kind) unless g.present?
    f = g.add_manual_field(item, options)
  end
  alias_method :add_field, :add_custom_field_to_default_group

  # only custom field plugin (protected)
  # example:
  # id: custom_field_id
  # {
  # :key : {id: 123, values: ['uno','dos']}
  # :key2 : {id: 455, values: ['uno','dos']}
  # :key3 : {id: 4555, values: ['uno','dos']}
  # }
  def set_field_values(datas = {})
    ids_old = self.field_values.pluck(:id)
    ids_saved = []
    if datas.present?
      datas.each do |key, values|
        if values[:values].present?
          order_value = 0
          values[:values].each do |value|
            item = self.field_values.where({custom_field_id: values[:id], custom_field_slug: key, value: fix_meta_value(value)}).first_or_create!()
            if defined?(item.id)
              item.update_column('term_order', order_value)
              ids_saved << item.id
              order_value += 1
            end
          end
        end
      end
    end

    ids_deletes = ids_old - ids_saved
    self.field_values.where(id: ids_deletes).destroy_all if ids_deletes.present?
  end

  # return field object for current model
  def get_field_object(slug)
    CamaleonCms::CustomField.where(parent_id: get_field_groups.pluck(:id), slug: slug).first || CamaleonCms::CustomField.where(slug: slug, parent_id: get_field_groups({include_parent: true})).first
  end

  # clear and register values for this custom field
  # key: slug of the custom field
  # value: array of values for multiple values support
  # value: string value
  def save_field_value(key, value, order = 0, clear = true)
    field = get_field_object(key)
    return unless field.present?
    self.field_values.where({custom_field_slug: key}).destroy_all if clear
    if value.is_a?(Array)
      value.each do |val|
        self.field_values.create!({custom_field_id: field.id, custom_field_slug: key, value: fix_meta_value(val), term_order: order})
      end
    else
      self.field_values.create!({custom_field_id: field.id, custom_field_slug: key, value: fix_meta_value(value), term_order: order})
    end
  end

  private
  def fix_meta_value(value)
    if (value.is_a?(Array) || value.is_a?(Hash))
      value = value.to_json
    end
    value
  end

  def _destroy_custom_field_groups
    class_name = self.class.to_s.parseCamaClass
    if ['Category','Post','PostTag'].include?(class_name)
      CamaleonCms::CustomFieldGroup.where(objectid: self.id, object_class: class_name).destroy_all
    elsif ['PostType'].include?(class_name)
      get_field_groups("Post").destroy_all
      get_field_groups("Category").destroy_all
      get_field_groups("PostTag").destroy_all
    elsif ["NavMenuItem"].include?(class_name) # menu items doesn't include field groups
    else
      get_field_groups().destroy_all if get_field_groups.present?
    end
  end
end
