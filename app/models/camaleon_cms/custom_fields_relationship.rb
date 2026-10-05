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
    # A field group can repeat on a record. The group number of a value says which copy of the group
    # holds the value, and the first copy has the number 0. PostgreSQL and MySQL store the number in a
    # 4-byte integer column, so 2147483647 is the largest number that each database can store.
    MAX_GROUP_NUMBER = 2_147_483_647
    # The largest length of a group number that the caller gives as a text. Rails 8.1.4 reads only the
    # first 16 bytes of a text when it changes the text to an integer. For a longer text, Rails stores
    # another number than the number that the validation checked. So a longer text is not valid.
    MAX_GROUP_NUMBER_DIGITS = 16

    # The attribute type of the group number.
    #
    # A caller can give the group number as a text. The integer type of Rails raises an encoding error
    # for a text with a broken encoding, and for a text in an encoding that is not ASCII-compatible
    # (UTF-16). This type gives nil for such a text and raises no error. The results:
    # - A row keeps the text as the caller gave it. The validation reads that text, so the caller
    #   gets the usual error of a group number that is not valid.
    # - where(group_number: text) and find_by(group_number: text) find no row.
    # - update_column, update_all with a hash and insert_all run no validation and no callback. They
    #   store NULL as the group number for such a text.
    #
    # The type has the range of a 4-byte integer (-2147483648 to 2147483647) on each database. SQLite
    # and a bigint column can hold a larger number, and the maintainer chose to keep the 4-byte range
    # there too. For a number n outside that range:
    # - where(group_number: n) and find_by(group_number: n) find no row, also when a row holds n.
    # - A write of n that runs no validation raises ActiveModel::RangeError (update_column,
    #   update_all with a hash, insert_all).
    # - An SQL text is not checked: where('group_number = ?', n) finds the row.
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
    # update_attribute and save(validate: false) run no validation. Without this callback, such a save
    # stores NULL for a group number text that the type cannot read (see GroupNumberType). The
    # callback stops the save with the error of the group number: save returns false, and save!
    # raises ActiveRecord::RecordInvalid.
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

    # The error message for a group number that is not valid.
    def group_number_refusal
      cama_rejection_message('group_number_invalid', max: MAX_GROUP_NUMBER)
    end

    # Raises ActiveRecord::RecordInvalid when the group number of this row is not valid. It does
    # nothing for a valid number. set_field_value and set_field_values call it on a row that they do
    # not store, to check a group number when they build no row: a call with an empty list of values,
    # or an entry with no values.
    def refuse_invalid_group_number!
      raise_group_number_refusal if group_number_refused?
    end

    # Gives a copy of a row (dup) the group number as the caller gave it to the original row.
    #
    # Rails copies each attribute after the integer cast, and the cast changes a group number that is
    # not valid to a valid one: 'abc' becomes 0, and true becomes 1. Without this method, the copy of a
    # row with the group number 'abc' is valid, and its save stores group 0. With the group number as
    # given, the copy gets the same error as the original row.
    #
    # A copy is a new row, and a new row is always checked. So the copy of a stored row is not valid
    # when that row holds a negative number or a number above 2147483647. A row from an earlier
    # release can hold such a number. The maintainer chose to keep this.
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

    # Whether the validation must check the group number.
    # - A new row is always checked.
    # - A stored row is checked only when the save changes its group number. So a stored row with a
    #   negative number from an earlier release stays valid when a caller changes only its value.
    # - A row with a group number text that the type cannot read is always checked. On a stored row
    #   with no group number, Rails sees no change for that text, because the type reads it as nil.
    def group_number_given?
      new_record? || will_save_change_to_group_number? || group_number_unreadable?
    end

    # Whether the caller gave a group number text that the type cannot read: a text with a broken
    # encoding, or in an encoding that is not ASCII-compatible.
    def group_number_unreadable?
      GroupNumberType.unreadable?(group_number_before_type_cast)
    end

    # Raises ActiveRecord::RecordInvalid with the error of the group number. It adds the message to
    # the errors of the row only when the row does not hold that message.
    def raise_group_number_refusal
      refusal = group_number_refusal
      errors.add(:base, refusal) unless errors.added?(:base, refusal)
      raise ActiveRecord::RecordInvalid, self
    end

    def reject_invalid_group_number
      errors.add(:base, group_number_refusal) if group_number_refused?
    end

    # Whether the group number is not valid. The check reads the number as the caller gave it, before
    # the integer cast of Rails. After the cast, a group number that is not valid looks valid: 'abc'
    # becomes 0, and true becomes 1. Without the check, a number above 2147483647 raises
    # ActiveModel::RangeError at the save. nil is valid: a row can have no group number.
    def group_number_refused?
      given = group_number_before_type_cast
      !(given.nil? || storable_group_number?(given))
    end

    # Whether the given group number is an integer from 0 to 2147483647. The caller can give it as an
    # Integer, or as a text of 1 to 16 ASCII digits.
    # - A value of each other class is not valid, also a Symbol that prints as digits (:'5').
    # - The size of a text is checked first, so the method does not scan a very long text.
    # - A text that the type cannot read is not valid. The digits check raises an error for such a
    #   text, so that test comes before the digits check.
    def storable_group_number?(given)
      return given.between?(0, MAX_GROUP_NUMBER) if given.is_a?(Integer)
      return false unless given.is_a?(String) && given.bytesize <= MAX_GROUP_NUMBER_DIGITS
      return false if GroupNumberType.unreadable?(given)

      given.match?(/\A\d+\z/) && given.to_i <= MAX_GROUP_NUMBER
    end

    # Gives the error message for the key in the current language, or in English when that language
    # has no translation of the key.
    #
    # The current language is the language of the admin or of the site. Only en.yml has each message
    # of this model. The other admin locale files have only the message of the group number, and some
    # languages have no admin locale file. Without the English fallback, the admin sees
    # "translation missing" in those languages.
    #
    # The fallback is the English text with its placeholders, so I18n fills in the slug and the other
    # values one time. A fallback with the values already filled in can fail: a slug can hold the
    # placeholder syntax of I18n, and I18n then raises an error for a placeholder with no value.
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
