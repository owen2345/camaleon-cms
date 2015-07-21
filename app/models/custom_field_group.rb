class CustomFieldGroup < CustomField
  # attrs required: name, slug, description
  default_scope { where.not(object_class: '_fields').reorder('custom_fields.field_order ASC') }

  has_many :metas, ->{ where(object_class: 'CustomFieldGroup')}, :class_name => "Meta", foreign_key: :objectid, dependent: :destroy
  has_many :fields, -> {where(object_class: '_fields')}, :class_name => "CustomField", foreign_key: :parent_id, dependent: :destroy
  belongs_to :site, :class_name => "Site", foreign_key: :parent_id
  before_validation :before_validating

  # ------------------- fields -----------------
  # add fields to group
  # item:
  # -  sample:  {"name"=>"Label", "slug"=>"my_slug", "description"=>"my description (optional)"}
  # -  options (textbox sample):  {"field_key":"text_box","multiple":"1","required":"1","translate":"1"}

  # check all options for each case in Admin::CustomFieldsHelper
  # for select, radio and checkboxes add:
  # -- multiple_options: [{"title"=>"Option Title", "value"=>"2", "default"=>"1"}, {"title"=>"abcde", "value"=>"3"}]
  # -- add default for default value

  def add_manual_field(item, options)
    c = get_field(item[:slug] || item["slug"])
    return c if c.present?

    field_item = self.fields.create!(item)
    field_item.set_meta('_default', options)
    auto_save_default_values(field_item, options)
    field_item
  end
  alias_method :add_field, :add_manual_field

  # return a field with slug = slug from current group
  def get_field(slug)
    self.fields.where(slug: slug).first
  end

  # only used by form on admin panel (protected)
  def add_fields(items, item_options)
    ids_old = self.fields.pluck('custom_fields.id')
    ids_saved = []
    order_index = 0
    if items.present?
      items.each do |i,item|
        item[:field_order] = order_index
        options = item_options[i] || {}
        if item[:id].present?
          field_item = self.fields.find(item[:id])
          saved = field_item.update(item)
        else
          field_item = self.fields.new(item)
          saved = field_item.save
          auto_save_default_values(field_item, options) if saved
        end
        if saved
          field_item.set_meta('_default', options)
          ids_saved << field_item.id
          order_index += 1
        end
      end
    end
    ids_deletes = ids_old - ids_saved
    self.fields.where(id: ids_deletes).destroy_all if ids_deletes.present?
  end

  # generate the caption for this group
  def get_caption
    caption = ""
    begin
      case self.object_class
        when "PostType_Post"
          caption = "Fields for Contents in <b>#{self.site.post_types.find(self.objectid).decorate.the_title}</b>"
        when 'PostType_Category'
          caption = "Fields for Categories in <b>#{self.site.post_types.find(self.objectid).decorate.the_title}</b>"
        when 'PostType_PostTag'
          caption = "Fields for Post tags in <b>#{self.site.post_types.find(self.objectid).decorate.the_title}</b>"
        when 'Widget::Main'
          caption = "Fields for Widget <b>(#{Widget::Main.find(self.objectid).name.translate})</b>"
        when 'Theme'
          caption = "Field settings for Theme <b>(#{self.objectid})</b>"
        when 'Site'
          caption = "Field settings the site"
        when 'PostType'
          caption = "Fields for all <b>Post_Types</b>"
        when 'Post'
          p = Post.find(self.objectid).decorate
          caption = "Fields for content <b>(#{p.the_title})</b>"
        else # 'Plugin' or other class
          caption = "Fields for <b>#{self.object_class}</b>"
      end
    rescue => e
      Rails.logger.info "----------#{e.message}----#{self.attributes}"
    end
    caption
  end

  private
  def before_validating
    self.slug = "_group-#{self.name.to_s.parameterize}" unless self.slug.present?
  end

  # auto save the default field values
  def auto_save_default_values(field, options)
    class_name = self.object_class.split("_").first
    if ["Post", "Category", "Plugin", "Theme"].include?(class_name) && self.objectid.present? && options[:default_value].present?
      if class_name == "Theme"
        owner = class_name.constantize.where(slug: self.objectid, parent_id: self.parent_id).first # owner model
      else
        owner = class_name.constantize.find(self.objectid) rescue class_name.constantize.where(slug: self.objectid).first # owner model
      end
      owner.field_values.create!({custom_field_id: field.id, custom_field_slug: field.slug, value: fix_meta_value(options["default_value"]||options[:default_value])}) if owner.present?
    end
  end
end
