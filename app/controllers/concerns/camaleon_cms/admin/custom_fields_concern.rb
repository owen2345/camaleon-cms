module CamaleonCms
  module Admin
    module CustomFieldsConcern
      extend ActiveSupport::Concern

      private

      # Only permit field values whose slug is registered under object_class. param_key selects
      # which request param carries the payload, so sibling params (the theme form's
      # theme_fields) get the same allowed-slugs permit as the default field_options.
      def cama_permitted_field_options(object_class, param_key: :field_options)
        return {} if params[param_key].blank?

        allowed_keys = cama_custom_field_allowed_slugs(object_class)
        return {} if allowed_keys.blank?

        field_options = params.require(param_key)
        field_options.permit(field_options.keys.select { |k| k.to_s =~ /\A\d+\z/ }.index_with do
          allowed_keys.index_with { [:id, :group_number, { values: {} }] }
        end).to_h
      end

      def cama_custom_field_allowed_slugs(object_class)
        CamaleonCms::CustomField.where(
          parent_id: CamaleonCms::CustomField.where(object_class: object_class).select(:id),
          object_class: '_fields'
        ).pluck(:slug).uniq
      end
    end
  end
end
