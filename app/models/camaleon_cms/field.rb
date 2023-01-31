# frozen_string_literal: true

module CamaleonCms
  class Field < ActiveRecord::Base
    include CamaleonCms::Metas
    attr_accessor :settings

    self.table_name = "#{PluginRoutes.static_system_info['db_prefix']}fields"
    belongs_to :field_group, required: true

    validates :name, :slug, presence: true
    validates_uniqueness_of :slug, scope: :field_group_id

    before_save :fix_default_value, if: :settings
    after_save :save_settings, if: :settings
    scope :ordered, -> { order(position: :asc) }
    scope :exclude_keys, ->(keys) { where.not(slug: keys) }

    private

    def fix_default_value
      enabled_trans = settings[:translate].to_bool
      return if enabled_trans

      default_value = settings[:default_value].translations_array.find(&:present?)
      settings[:default_value] = default_value
    end

    def save_settings
      set_options(settings)
    end
  end
end
