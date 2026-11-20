module CamaleonCms
  module Admin
    module CustomFieldsConcern
      extend ActiveSupport::Concern

      # The filter of one field entry (`field_options[<index>][<slug>]`). `values` arrives keyed by
      # index (`values[<index>]`, as the admin JavaScript renames the inputs of most fields) or as a
      # list of scalars (`values[]`, the checkboxes field). A `values` filter that does not match the
      # shape leaves the result of the other one in place.
      #
      # A list that holds a hash (`values[][attr]`) matches no filter, so the entry keeps no values
      # (intended). No admin form sends that list: the admin JavaScript renames the inputs of the
      # field_attrs field to `values[<index>][attr]`.
      #
      # `{ group_number: [{}] }` keeps a group number that the request sends as a list or a hash, with
      # its content removed. The value then fails its validation. With `:group_number` alone, Rails
      # drops such a group number, and the value goes to group 0 with no error.
      FIELD_ENTRY_FILTER = [:id, :group_number, { values: {} }, { values: [] }, { group_number: [{}] }].freeze
      private_constant :FIELD_ENTRY_FILTER

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
        return {} if field_ids.blank?

        # A group is the value of a key of digits only (`field_options[<index>]`), and it holds one
        # entry for each field slug. The helper reads these two levels itself, and Rails permits one
        # entry at a time. With a nested filter for the groups, Rails reads a group that holds a numeric
        # key with a hash value as nested attributes, and keeps only its numeric keys. From Rails 7.0,
        # Rails does not do this when the filter names a numeric key. A field slug of digits only, such
        # as `2020`, is such a key.
        #
        # A group with no entry of an allowed slug is not in the result: set_field_values deletes each
        # stored value before it writes, so a payload that holds only such groups must stay blank.
        permitted = ActiveSupport::HashWithIndifferentAccess.new
        field_options.each_pair do |index, group|
          next unless index.to_s.match?(/\A\d+\z/) && group.is_a?(ActionController::Parameters)

          fields = cama_permitted_field_entries(group, field_ids)
          permitted[index] = fields if fields.present?
        end
        permitted
      end

      # The entry of each allowed slug of one group, in the order of field_ids. An entry that is a
      # scalar or a list has no id and no values to read, so it is not in the result.
      def cama_permitted_field_entries(group, field_ids)
        field_ids.each_with_object(ActiveSupport::HashWithIndifferentAccess.new) do |(slug, ids), fields|
          entry = group[slug]
          next unless entry.is_a?(ActionController::Parameters)

          data = entry.permit(FIELD_ENTRY_FILTER).to_h
          # The value gate picks its check from the field the row points at, and set_field_values falls
          # back to this id where the groups it resolves slugs in hold no field of that slug (a caller that
          # permits against other groups than it saves with, a class-only permit among them). Hold it to
          # the slug's own fields, so a forged id naming another field (a text box for a url slug)
          # cannot change the rules of the gate.
          data[:id] = ids.find { |id| id.to_s == data[:id].to_s } || ids.first
          fields[slug] = data
        end
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
