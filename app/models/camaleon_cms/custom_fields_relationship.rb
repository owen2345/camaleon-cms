module CamaleonCms
  class CustomFieldsRelationship < CamaleonRecord
    self.table_name = "#{PluginRoutes.static_system_info['db_prefix']}custom_fields_relationships"

    # attr_accessible :objectid, :custom_field_id, :term_order, :value, :object_class,
    # :custom_field_slug, :group_number
    default_scope { order("#{CamaleonCms::CustomFieldsRelationship.table_name}.term_order ASC") }

    # relations
    belongs_to :custom_field, class_name: 'CamaleonCms::CustomField', optional: true
    belongs_to :owner, polymorphic: true, foreign_key: :objectid, foreign_type: :object_class, optional: true

    # validates :objectid, :custom_field_id, presence: true
    validates :custom_field_id, presence: true # error on clone model

    # Rendered positions that need a save-time gate (audit M17, scan-and-reject policy). An
    # `editor` value is emitted as markup (`raw`); a `field_attrs` value is a JSON pair whose
    # members are emitted as markup; the URI field types are emitted into href/src. Every other
    # field type's value renders through escaping ERB as element content, where markup cannot
    # execute, so it needs no gate.
    MARKUP_FIELD_KEYS = %w[editor].freeze
    JSON_MARKUP_FIELD_KEYS = %w[field_attrs].freeze
    URI_FIELD_KEYS = %w[url image audio video file].freeze

    validate :reject_untrusted_dangerous_value

    after_save :set_parent_slug
    after_save :update_model_owner # TODO: convert this model into polymorphic

    # Opt-out for trusted server-side pipelines (imports, seeds, plugin code), mirroring
    # Post#unfiltered_content!: a reader plus a bang enabler and NO writer, so mass assignment
    # cannot reach it. Sticky for the lifetime of the instance.
    attr_reader :unfiltered_value

    def unfiltered_value!
      @unfiltered_value = true
      self
    end

    private

    # Security (audit M17): the frontend renders an `editor` value verbatim and URI-type values
    # into URL positions, so a value an untrusted author may not write is refused — never
    # rewritten. Stored values therefore always equal authored values.
    def reject_untrusted_dangerous_value
      return if value.blank? || unfiltered_value

      field_key = custom_field&.options&.[](:field_key).to_s
      if MARKUP_FIELD_KEYS.include?(field_key)
        return if author_trusted_for_unfiltered_value?
        return unless CamaleonCms::UnsafeMarkup.unsafe_html?(
          value, tags: CamaleonCms::Post::CONTENT_ALLOWED_TAGS,
                 attributes: CamaleonCms::Post::CONTENT_ALLOWED_ATTRIBUTES
        )

        errors.add(:base, cama_rejection_message('value_rejected_html'))
      elsif JSON_MARKUP_FIELD_KEYS.include?(field_key)
        return if author_trusted_for_unfiltered_value?

        unsafe_member = json_member_values(value).any? do |member|
          CamaleonCms::UnsafeMarkup.unsafe_html?(
            member, tags: CamaleonCms::Post::CONTENT_ALLOWED_TAGS,
                    attributes: CamaleonCms::Post::CONTENT_ALLOWED_ATTRIBUTES
          )
        end
        return unless unsafe_member

        errors.add(:base, cama_rejection_message('value_rejected_html'))
      elsif URI_FIELD_KEYS.include?(field_key)
        return if author_trusted_for_unfiltered_value?
        return unless CamaleonCms::UnsafeMarkup.dangerous_uri?(value)

        errors.add(:base, cama_rejection_message('value_rejected_uri'))
      end
    end

    # A field_attrs value stores a JSON {attr:, value:} pair whose members render verbatim. Scan
    # the DECODED members, not the stored bytes: the Rails JSON encoder unicode-escapes angle
    # brackets (escape_html_entities_in_json stores \u003c instead of a literal <), so a
    # byte-level scan of the stored string would pass markup that JSON.parse restores at render.
    # Unparseable values are scanned as-is (fail closed on whatever the renderer would fall back to).
    def json_member_values(value)
      parsed = JSON.parse(value)
      parsed.is_a?(Hash) ? parsed.values.map(&:to_s) : [value.to_s]
    rescue JSON::ParserError
      [value.to_s]
    end

    # The message must never be swallowed by a missing translation: only en.yml carries these keys,
    # while the process locale follows the current admin/site language — fall back to English.
    def cama_rejection_message(key)
      full_key = "camaleon_cms.admin.custom_field.message.#{key}"
      I18n.t(full_key, slug: custom_field_slug,
                       default: I18n.t(full_key, slug: custom_field_slug, locale: :en))
    end

    # Trust follows the post-content model: an admin may write anything; a post's field values may
    # skip the gate when the saver holds post_content_unfiltered_html for the post type. Fails
    # closed (the gate applies) without a request context — benign values still pass the scan.
    def author_trusted_for_unfiltered_value?
      user = CurrentRequest.user
      site = CurrentRequest.site
      return false if user.blank? || site.blank?
      return true if user.admin?

      parent = owner
      return false unless parent.is_a?(CamaleonCms::Post) && parent.post_type.present?

      CamaleonCms::Ability.new(user, site).can?(:post_content_unfiltered_html, parent.post_type)
    end

    def set_parent_slug
      # self.update_column('custom_field_slug', self.custom_fields.slug)
    end

    # touch owner model
    def update_model_owner
      "CamaleonCms::#{object_class}".constantize.find(objectid).touch # rubocop:disable Rails/SkipsModelValidations
    rescue StandardError
      nil
    end
  end
end
