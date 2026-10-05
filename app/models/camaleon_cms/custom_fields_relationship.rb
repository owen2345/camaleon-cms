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
    # A group number is an index from 0. PostgreSQL and MySQL store it in a 4-byte integer column.
    MAX_GROUP_NUMBER = 2_147_483_647

    # The integer type of the group number. The integer type of Rails raises its own error for a text
    # with a broken encoding, or in an encoding that is not ASCII-compatible (UTF-16). This type reads
    # that text as no number, in a row and in a lookup. The row keeps the text, and the validation
    # refuses it.
    #
    # update_column, update_all and insert_all skip the validation and the callbacks. They store no
    # group number for that text.
    #
    # The type has the 4-byte range on each database, as the validation has. The design keeps this
    # range where the column holds a wider integer (SQLite, a bigint column). There, a lookup with a
    # number above the range finds no row, and a write that skips the validation raises
    # ActiveModel::RangeError for it.
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
    # A save that skips the validation must not store a group number text that the type cannot read:
    # the type reads that text as no number. In that save, save returns false and save! raises the
    # refusal.
    before_save :refuse_invalid_group_number!, if: :group_number_unreadable?
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

    # The message of the refusal of a group number.
    def group_number_refusal
      cama_rejection_message('group_number_invalid', max: MAX_GROUP_NUMBER)
    end

    # Raises the refusal of the row when the row refuses its group number. set_field_value calls it
    # before its delete, because a call with an empty list builds no row. The before_save guard calls
    # it for a text that the type cannot read.
    def refuse_invalid_group_number!
      raise_group_number_refusal if group_number_refused?
    end

    # A copy takes the cast value of each attribute, and the cast hides a group number that the row
    # refuses ('abc' becomes 0). The copy keeps the group number as the caller gave it.
    # A copy is a new row, so the row checks its group number. The copy of a stored row that holds a
    # negative number, or a number above the range, gets the refusal. The design keeps this refusal.
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

    # A stored row that holds a negative group number stays valid until a caller changes the number.
    # The type reads an unreadable text as no number, which is no change on a row with no number.
    def group_number_given?
      new_record? || will_save_change_to_group_number? || group_number_unreadable?
    end

    # The row holds a text that the integer type cannot read.
    def group_number_unreadable?
      GroupNumberType.unreadable?(group_number_before_type_cast)
    end

    # Raises the refusal of the row. The row holds the message one time.
    def raise_group_number_refusal
      refusal = group_number_refusal
      errors.add(:base, refusal) unless errors.added?(:base, refusal)
      raise ActiveRecord::RecordInvalid, self
    end

    def reject_invalid_group_number
      errors.add(:base, group_number_refusal) if group_number_refused?
    end

    # A number above the column range raises ActiveModel::RangeError at the save, and the integer cast
    # hides a boolean or a text ('abc' becomes 0). The check reads the group number as the caller gave
    # it. A nil group number passes: a caller can leave it unset.
    def group_number_refused?
      given = group_number_before_type_cast
      !(given.nil? || storable_group_number?(given))
    end

    # An Integer or a text of ASCII digits. A Symbol can print as digits, and the cast makes it nil.
    # The digits check raises for a text that the type cannot read.
    def storable_group_number?(given)
      return false unless given.is_a?(Integer) || given.is_a?(String)
      return false if GroupNumberType.unreadable?(given)

      given.to_s.match?(/\A\d+\z/) && given.to_i <= MAX_GROUP_NUMBER
    end

    # A missing translation must not hide the message. The process locale follows the language of the
    # admin or the site. Only en.yml carries each key. The other admin files carry the key of the
    # group number only, and a language with no admin file carries none. The message falls back to
    # English.
    #
    # The fallback is the English template with no values, so I18n fills the values one time. A slug
    # can hold the interpolation syntax of I18n, and a second pass raises an error for that slug.
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
