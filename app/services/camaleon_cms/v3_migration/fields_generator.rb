# frozen_string_literal: true
# TODO: test tasks, add rspec tests

module CamaleonCms
  module V3Migration
    class FieldsGenerator < ApplicationService
      def initialize
        @failed_groups = []
        @failed_fields = []
        @failed_values = []
      end

      def call
        CamaleonCms::FieldGroup.transaction do
          copy_field_groups
          copy_field_values
        end
        log('The following field groups were not migrated: ', :error, @failed_groups) if @failed_groups.any?
        log('The following fields were not migrated: ', :error, @failed_fields) if @failed_fields.any?
        log('The following field values were not migrated: ', :error, @failed_values) if @failed_values.any?
      end

      def self.revert
        CamaleonCms::FieldValue.delete_all
        CamaleonCms::FieldGroup.destroy_all
      end

      private

      def copy_field_groups
        table = "#{PluginRoutes.static_system_info['db_prefix']}custom_fields"
        sql = "Select * from #{table} where object_class != '_fields'"
        run_query(sql).each do |item|
          save_group(item)
        rescue => e
          e.message.include?('Site must exist') ? @failed_groups.push([item, e.message]) : raise
        end
      end

      def save_group(item)
        model = "CamaleonCms::#{item['object_class'].split('_').first}".constantize.find(item['objectid'])
        parsed_data = { position: item['field_order'], repeat: item['is_repeat'] }
                        .merge(item.slice('id', 'name', 'description', 'slug'))
        group = case item['object_class']
                when 'PostType_Post', 'PostType_Category', 'PostType_PostTag'
                  kind = item['object_class'].split('_').last
                  model.field_groups.create!(parsed_data.merge(kind: kind))
                when 'Post', 'Site'
                  model.self_field_groups.create!(parsed_data)
                else
                  model.field_groups.create!(parsed_data)
                end
        copy_fields(group, item['id'])
      end

      def copy_fields(group, group_id)
        table = "#{PluginRoutes.static_system_info['db_prefix']}custom_fields"
        sql = "Select * from #{table} where object_class = '_fields' and parent_id=#{group_id}"
        run_query(sql).each do |item|
          save_field(group, item)
        rescue => e
          @failed_fields.push([group_id, item, e.message])
        end
      end

      def save_field(group, item)
        parsed_data = { position: item['field_order'] }.merge(item.slice('id', 'name', 'description', 'slug'))
        group.fields.create!(parsed_data)
      end

      def copy_field_values
        table = "#{PluginRoutes.static_system_info['db_prefix']}custom_fields_relationships"
        run_query("Select * from #{table}").each do |item|
          model = "CamaleonCms::#{item['object_class'].split('_').first}".constantize.find(item['objectid'])
          data = { field_slug: item['custom_field_slug'], position: item['term_order'] }
                   .merge(item.slice('id', 'value', 'group_number'))
          model.field_values.create!(data)
        rescue => e
          @failed_values.push([item, e.message])
        end
      end
    end
  end
end
