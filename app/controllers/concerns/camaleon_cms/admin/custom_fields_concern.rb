module CamaleonCms
  module Admin
    module CustomFieldsConcern
      extend ActiveSupport::Concern

      private

      # Only permit field values whose slug is registered under object_class. param_key selects
      # which request param carries the payload, so sibling params (the theme form's
      # theme_fields) get the same allowed-slugs permit as the default field_options.
      def cama_permitted_field_options(object_class, param_key: :field_options)
        field_options = params[param_key]
        # A non-hash payload (a scalar `field_options=foo`, or an array) carries no groups to permit,
        # so treat it as empty instead of calling #keys/#permit on it. Guarding here rather than
        # `params.require` avoids a NoMethodError -> 500 an authenticated caller could trigger with a
        # malformed param (the same crash every set_field_values caller shared).
        return {} unless field_options.is_a?(ActionController::Parameters)

        allowed_keys = cama_custom_field_allowed_slugs(object_class)
        return {} if allowed_keys.blank?

        permitted = field_options.permit(field_options.keys.select { |k| k.to_s =~ /\A\d+\z/ }.index_with do
          allowed_keys.index_with { [:id, :group_number, { values: {} }] }
        end).to_h
        # Drop groups left empty after filtering. set_field_values deletes every existing value
        # before writing, so handing it a non-blank-but-empty payload (a group whose submitted
        # slugs were all unregistered) would wipe the object's stored values and write nothing.
        permitted.reject { |_group, fields| fields.blank? }
      end

      # The allow-list covers fields registered directly under object_class. For a post
      # ('PostType_Post') this intentionally spans only the post type's own groups -- not per-post
      # ('Post') or category-inherited ('Category_Post') groups the edit form also renders. It
      # matches PostsController#save_post_with_fields, so the main post save and drafts confine field
      # writes identically; values for those sibling scopes are deliberately not written this way.
      def cama_custom_field_allowed_slugs(object_class)
        CamaleonCms::CustomField.where(
          parent_id: CamaleonCms::CustomField.where(object_class: object_class).select(:id),
          object_class: '_fields'
        ).pluck(:slug).uniq
      end
    end
  end
end
