module CamaleonCms
  module Admin
    module CustomFieldsConcern
      extend ActiveSupport::Concern

      private

      # Only permit field values whose slug is registered under object_class. param_key selects
      # which request param carries the payload, so sibling params (the theme form's
      # theme_fields) get the same allowed-slugs permit as the default field_options.
      # field_groups confines the permit to one record: pass the field-group relation the save's
      # form renders (the `field_groups` local of the custom_fields/render partial, e.g.
      # `@plugin.get_field_groups`), and only those groups' fields are permitted. Without it every
      # group placed with object_class counts, on any record and any site, as released callers expect.
      def cama_permitted_field_options(object_class, param_key: :field_options, field_groups: nil)
        field_options = params[param_key]
        # A non-hash payload (a scalar `field_options=foo`, or an array) carries no groups to permit,
        # so treat it as empty instead of calling #keys/#permit on it. Guarding here rather than
        # `params.require` avoids a NoMethodError -> 500 an authenticated caller could trigger with a
        # malformed param (the same crash every set_field_values caller shared).
        return {} unless cama_hash_param?(field_options) && field_options.respond_to?(:permit)

        allowed_keys = cama_custom_field_allowed_slugs(object_class, field_groups: field_groups)
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
      # With field_groups (a CustomFieldGroup relation, what the form renders) the list is confined
      # to those groups' fields within object_class; a slug registered only on a sibling record of
      # the same class, or by another site, is not in it. The relation's field_order default scope
      # has no place inside the subquery.
      def cama_custom_field_allowed_slugs(object_class, field_groups: nil)
        groups = (field_groups || CamaleonCms::CustomField.all).where(object_class: object_class)
        CamaleonCms::CustomField.where(
          parent_id: groups.unscope(:order).select(:id),
          object_class: '_fields'
        ).pluck(:slug).uniq
      end
    end
  end
end
