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

        field_ids = cama_custom_field_ids_by_slug(object_class, field_groups: field_groups)
        allowed_keys = field_ids.keys
        return {} if allowed_keys.blank?

        # values arrives keyed by index (`values[<index>]`, as the admin JavaScript renames most fields'
        # inputs) or as a list of scalars (`values[]`, the checkboxes field). Each shape needs a filter
        # of its own, and the one that does not match leaves the other's result in place.
        permitted = field_options.permit(field_options.keys.select { |k| k.to_s =~ /\A\d+\z/ }.index_with do
          allowed_keys.index_with { [:id, :group_number, { values: {} }, { values: [] }] }
        end).to_h
        # Keep only hash-shaped groups and slug entries: a list of hashes passes the permit too and
        # carries no slug or id to read. Keep only the entries of an allowed slug. Rails reads a group
        # that holds a numeric key as nested attributes, so the entry under that key passes the permit.
        # Drop groups left empty after filtering: set_field_values
        # deletes every existing value before writing, so handing it a non-blank-but-empty payload (a
        # group whose submitted slugs were all unregistered) would wipe the stored values and write nothing.
        permitted.select! { |_group, fields| fields.is_a?(Hash) }
        permitted.each_value { |fields| fields.select! { |slug, data| data.is_a?(Hash) && field_ids.key?(slug) } }
        permitted.reject! { |_group, fields| fields.blank? }
        # The value gate picks its check from the field the row points at, and set_field_values falls
        # back to this id where the groups it resolves slugs in hold no field of that slug (a caller that
        # permits against other groups than it saves with, a class-only permit among them). Hold it to
        # the slug's own fields, so a forged id naming another field (a text box for an editor slug)
        # cannot skip the gate.
        permitted.each_value do |fields|
          fields.each do |slug, data|
            ids = field_ids[slug]
            data[:id] = ids.find { |id| id.to_s == data[:id].to_s } || ids.first
          end
        end
        permitted
      end

      # The allow-list covers fields registered directly under object_class. For a post
      # ('PostType_Post') this intentionally spans only the post type's own groups -- not per-post
      # ('Post') or category-inherited ('Category_Post') groups the edit form also renders. The post
      # and draft saves share that scope through PostsController#save_post_params; values for those
      # sibling scopes are deliberately not written this way.
      # With field_groups (a CustomFieldGroup relation, what the form renders) the list is confined
      # to those groups' fields within object_class; a slug registered only on a sibling record of
      # the same class, or by another site, is not in it. The relation's field_order default scope
      # has no place inside the subquery.
      def cama_custom_field_allowed_slugs(object_class, field_groups: nil)
        cama_custom_field_ids_by_slug(object_class, field_groups: field_groups).keys
      end

      # The allowed slugs, each with the ids of the fields registering it (see
      # cama_custom_field_allowed_slugs).
      def cama_custom_field_ids_by_slug(object_class, field_groups: nil)
        groups = (field_groups || CamaleonCms::CustomField.all).where(object_class: object_class)
        CamaleonCms::CustomField.where(
          parent_id: groups.unscope(:order).select(:id),
          object_class: '_fields'
        ).pluck(:slug, :id).group_by(&:first).transform_values { |pairs| pairs.map(&:last) }
      end
    end
  end
end
