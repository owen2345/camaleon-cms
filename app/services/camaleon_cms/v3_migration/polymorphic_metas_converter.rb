# frozen_string_literal: true

module CamaleonCms
  module V3Migration
    class PolymorphicMetasConverter < ApplicationService
      def call
        @failed = []
        CamaleonCms::Meta.all.find_each(&method(:parse_meta))
        log 'Following metas failed parsing class-name (skipped): ', :error, @failed if @failed.any?
      end

      def self.revert
        nil
      end

      private

      def parse_meta(meta)
        name = meta.object_class
        name = 'Field' if name == 'CustomField'
        name = 'FieldGroup' if name == 'CustomFieldGroup'
        name = 'FieldGroup' if name == 'CustomGroupField'
        model = "CamaleonCms::#{name.classify}".constantize
        meta.update_columns(record_type: model.base_class.name, record_id: meta.objectid)
      rescue => e
        @failed.push([meta.inspect, e.message])
      end
    end
  end
end
