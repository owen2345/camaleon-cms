module CamaleonCms
  class CustomFieldsRelationship < CamaleonRecord
    include CamaleonCms::ContentShortcodeGate

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
    GATED_FIELD_KEYS = (MARKUP_FIELD_KEYS + JSON_MARKUP_FIELD_KEYS + URI_FIELD_KEYS).freeze
    # An author can add a repeatable field group (is_repeat) to a post several times. For example, a
    # "Slide" group holds an image and a caption, and the author adds it one time for each slide.
    # group_number is the index of the slide that a value belongs to: 0 for the first slide, 1 for
    # the second. The largest index is the largest 4-byte integer. PostgreSQL and MySQL store the
    # column in 4 bytes.
    MAX_GROUP_NUMBER = 2_147_483_647
    # The largest size of a group number String. Rails 8.1.4 casts only the first 16 bytes of a
    # String to an Integer. So Rails stores a longer String as another number than the validated one.
    MAX_GROUP_NUMBER_DIGITS = 16

    # The Rails integer type with one change. Rails raises an encoding error for a String in an
    # invalid encoding or in an encoding such as UTF-16. This type returns nil for such a String.
    # The record keeps the String, so the validation reports an invalid group number.
    #
    # The range is 4 bytes on each database, also on SQLite and on a bigint column (intended).
    class GroupNumberType < ActiveRecord::Type::Integer
      def self.unreadable?(value)
        value.is_a?(String) && !(value.valid_encoding? && value.encoding.ascii_compatible?)
      end

      def cast(value)
        super unless self.class.unreadable?(value)
      end

      def serialize(value)
        super unless self.class.unreadable?(value)
      end
    end

    attribute :group_number, GroupNumberType.new

    validate :reject_untrusted_dangerous_value
    validate :reject_invalid_group_number, if: :group_number_given?
    # update_attribute and save(validate: false) skip the validation, and they store NULL for a String
    # that the type cannot cast. This callback refuses such a String: save and update_attribute return
    # false, and save! raises ActiveRecord::RecordInvalid.
    before_save :raise_group_number_refusal, if: :group_number_unreadable?
    # Any custom-field value is expanded by do_shortcode at render (CustomFieldsConcern#the_field
    # and friends), regardless of field type, so gate a shortcode in ANY value behind
    # content_shortcodes -- broader than the HTML gate above, which only covers markup/URI field
    # types.
    gate_content_shortcodes :value

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

    # The error message of an invalid group number.
    def group_number_refusal
      cama_rejection_message('group_number_invalid', max: MAX_GROUP_NUMBER)
    end

    # Raises ActiveRecord::RecordInvalid for an invalid group number. The writers call it on an
    # unsaved record: set_field_value before it deletes stored values, and set_field_values for an
    # entry with no values.
    def refuse_invalid_group_number!
      raise_group_number_refusal if group_number_refused?
    end

    # Rails copies (dup) each attribute after the type cast, which changes 'abc' to a valid 0. So this
    # method copies the group number before the cast, and the copy of an invalid record is invalid.
    #
    # A copy is a new record, and a new record is always validated. So the copy of a stored record
    # with a negative number from an earlier release is invalid (intended).
    def initialize_dup(other)
      super
      self[:group_number] = other.group_number_before_type_cast
    end

    class << self
      # Whether this field type's value is emitted into a markup or URL position (so it is gated).
      def gated_field_key?(field_key)
        GATED_FIELD_KEYS.include?(field_key.to_s)
      end

      # Why the save-time gate would refuse this value for the field type, or nil if it passes:
      # :too_large (over the parse ceiling), :html (disallowed markup), :uri (script-capable URL).
      # Ignores author trust, so the validation (trust-gated) and the scan_content rake task (which
      # reports every stored row) share one dispatch and cannot drift.
      def gate_rejection_reason(field_key, value)
        return if value.blank?

        key = field_key.to_s
        if MARKUP_FIELD_KEYS.include?(key)
          markup_rejection_reason(value)
        elsif JSON_MARKUP_FIELD_KEYS.include?(key)
          return :too_large if CamaleonCms::UnsafeMarkup.too_large?(value)

          :html if json_member_values(value).any? { |member| markup_unsafe?(member) }
        elsif URI_FIELD_KEYS.include?(key)
          :uri if CamaleonCms::UnsafeMarkup.dangerous_uri?(value)
        end
      end

      private

      def markup_rejection_reason(value)
        return :too_large if CamaleonCms::UnsafeMarkup.too_large?(value)

        :html if markup_unsafe?(value)
      end

      def markup_unsafe?(value)
        CamaleonCms::UnsafeMarkup.unsafe_html?(
          value, tags: CamaleonCms::Post::CONTENT_ALLOWED_TAGS,
                 attributes: CamaleonCms::Post::CONTENT_ALLOWED_ATTRIBUTES
        )
      end

      # A field_attrs value stores JSON whose string members render verbatim. Scan every DECODED
      # member (Hash, Array or nested), not the stored bytes: the Rails JSON encoder unicode-escapes
      # angle brackets (storing the escape instead of a literal bracket), so a byte-level scan of the
      # stored string would pass markup that JSON.parse restores at render. Unparseable values are
      # scanned as-is (fail closed on whatever the renderer would fall back to).
      def json_member_values(value)
        flatten_json_strings(JSON.parse(value))
      rescue JSON::ParserError
        [value.to_s]
      end

      def flatten_json_strings(node)
        case node
        when Hash then node.values.flat_map { |member| flatten_json_strings(member) }
        when Array then node.flat_map { |member| flatten_json_strings(member) }
        else [node.to_s]
        end
      end
    end

    private

    # Security (audit M17): the frontend renders an `editor`/`field_attrs` value verbatim and
    # URI-type values into URL positions, so a value an untrusted author may not write is refused --
    # never rewritten. Stored values therefore always equal authored values. The scan/dispatch lives
    # in the class-level gate_rejection_reason so the scan_content rake task reuses it verbatim.
    def reject_untrusted_dangerous_value
      return if value.blank? || unfiltered_value

      field_key = custom_field&.options&.[](:field_key).to_s
      return unless self.class.gated_field_key?(field_key)
      return if author_trusted_for_unfiltered_value?

      reason = self.class.gate_rejection_reason(field_key, value)
      return unless reason

      errors.add(:base, cama_rejection_message(rejection_message_key(reason)))
    end

    def rejection_message_key(reason)
      case reason
      when :too_large then 'value_too_large'
      when :uri then 'value_rejected_uri'
      else 'value_rejected_html'
      end
    end

    # Validate the group number of a new record always, and of a stored record only when the number
    # changes. So code can still update a stored record that holds a negative number from an earlier
    # release. A String that the type cannot cast is always validated, because Rails sees no change
    # from nil to it.
    def group_number_given?
      new_record? || will_save_change_to_group_number? || group_number_unreadable?
    end

    # Whether the group number is a String that the type cannot cast (see GroupNumberType).
    def group_number_unreadable?
      GroupNumberType.unreadable?(group_number_before_type_cast)
    end

    # Raises ActiveRecord::RecordInvalid with the group number error, and adds that error only once.
    def raise_group_number_refusal
      refusal = group_number_refusal
      errors.add(:base, refusal) unless errors.added?(:base, refusal)
      raise ActiveRecord::RecordInvalid, self
    end

    def reject_invalid_group_number
      errors.add(:base, group_number_refusal) if group_number_refused?
    end

    # Reads the group number before the type cast, because the cast hides an invalid one: 'abc'
    # becomes 0, and true becomes 1. nil is valid: a value can have no group number.
    def group_number_refused?
      given = group_number_before_type_cast
      !(given.nil? || storable_group_number?(given))
    end

    # True for an Integer from 0 to MAX_GROUP_NUMBER, and for a String of 1 to MAX_GROUP_NUMBER_DIGITS
    # digits with such a number ('5'). Each other class is invalid. The size test and the encoding
    # test come first, because the regexp raises an error for a String in an invalid encoding.
    def storable_group_number?(given)
      return given.between?(0, MAX_GROUP_NUMBER) if given.is_a?(Integer)
      return false unless given.is_a?(String) && given.bytesize <= MAX_GROUP_NUMBER_DIGITS
      return false if GroupNumberType.unreadable?(given)

      given.match?(/\A\d+\z/) && given.to_i <= MAX_GROUP_NUMBER
    end

    # The message in the current language, or in English when that language has no translation. Only
    # en.yml has each message of this model.
    #
    # The English default keeps its placeholders, so I18n fills in the slug one time. A slug can
    # hold the placeholder syntax of I18n, and a second interpolation then raises an error.
    def cama_rejection_message(key, **values)
      full_key = "camaleon_cms.admin.custom_field.message.#{key}"
      I18n.t(full_key, slug: custom_field_slug, **values, default: I18n.t(full_key, locale: :en))
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
