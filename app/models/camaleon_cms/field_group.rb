# frozen_string_literal: true

module CamaleonCms
  class FieldGroup < ActiveRecord::Base
    self.table_name = "#{PluginRoutes.static_system_info['db_prefix']}field_groups"
    include CamaleonCms::Metas
    include CamaleonCms::UnionScope

    alias_attribute :field_order, :position
    alias_attribute :is_repeat, :repeat

    belongs_to :site, required: true
    belongs_to :record, polymorphic: true
    has_many :fields, dependent: :destroy, inverse_of: :field_group

    before_validation :retrieve_site, unless: :site
    before_validation :generate_slug, unless: :slug
    before_update :force_save_fields_options
    validates :name, :slug, :record, presence: true
    validates_uniqueness_of :slug, scope: %i[record_type record_id site_id]

    accepts_nested_attributes_for :fields, allow_destroy: true
    scope :ordered, -> { order(position: :asc) }

    def add_manual_field(data, settings)
      fields.create!(data.merge(settings: settings))
    end

    def get_caption
      case record.class.name
      when 'CamaleonCms::Site'
        site_caption
      when 'CamaleonCms::Post'
        "#{caption_label(:common)} #{record.class.name.parseCamaClass} => #{ record.decorate.the_title }"
      when 'CamaleonCms::PostType'
        post_type_caption
      else
        "#{caption_label(:common)} #{record.class.name.parseCamaClass} => #{ record.decorate.the_title }"
      end
    end

    private

    def retrieve_site
      self.site ||= record.is_a?(CamaleonCms::Site) ? record : record.site
    end

    def site_caption
      case kind
      when 'User'
        caption_label(:users)
      when 'UserRole'
        caption_label(:user_roles)
      else
        caption_label(:site)
      end
    end

    def post_type_caption
      case kind
      when 'Post'
        "#{caption_label(:posts)} #{ record.decorate.the_title }"
      when 'Category'
        "#{caption_label(:categories)} #{ record.decorate.the_title }"
      when 'PostTag'
        "#{caption_label(:tags)} #{ record.decorate.the_title }"
      else
        "#{caption_label(:common)} #{record.class.name.parseCamaClass} => #{ record.decorate.the_title }"
      end
    end

    def caption_label(key)
      CamaleonCms::CamaleonHelper.cama_t("camaleon_cms.admin.settings.field_groups.type_labels.#{key}")
    end

    def generate_slug
      self.slug = "_group-#{name.to_s.parameterize}"
    end

    # Issue: field options are not auto-saved if field was not changed
    def force_save_fields_options
      fields.each{ |f| f.save! if !f.changed? && f.settings.present? }
    end
  end
end
