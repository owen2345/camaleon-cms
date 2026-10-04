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
    # write_attribute gives this Symbol to the integer cast in place of a group number text that the
    # cast cannot read. The validation refuses a Symbol.
    UNREADABLE_GROUP_NUMBER = :unreadable

    validate :reject_untrusted_dangerous_value
    validate :reject_invalid_group_number, if: :group_number_given?
    before_save :refuse_unreadable_group_number!
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

    # The message of the refusal of a group number, for the validation and for set_field_value.
    def group_number_refusal
      cama_rejection_message('group_number_invalid', max: MAX_GROUP_NUMBER)
    end

    # The integer cast of Rails raises its own error for a text that it cannot read, before the
    # validation runs. write_attribute keeps that text from the cast, and the validation refuses the row.
    def group_number=(value)
      write_attribute(:group_number, value)
    end

    # The writer above and []= call this method.
    def write_attribute(attr_name, value)
      unreadable = attr_name.to_s == 'group_number' && self.class.unreadable_group_number?(value)
      super(attr_name, unreadable ? UNREADABLE_GROUP_NUMBER : value)
    end

    # Raises the refusal of the row for a group number text that the cast cannot read. The cast makes
    # the Symbol of that text nil, and a save that skips the validation must not store that nil.
    # In that save, save returns false and save! raises the refusal.
    def refuse_unreadable_group_number!
      return unless group_number_unreadable?

      refusal = group_number_refusal
      errors.add(:base, refusal) unless errors[:base].include?(refusal)
      raise ActiveRecord::RecordInvalid, self
    end

    class << self
      # A text with a broken encoding, or in an encoding that is not ASCII-compatible (UTF-16). The
      # integer cast of Rails raises its own error for that text.
      def unreadable_group_number?(group_number)
        return false unless group_number.is_a?(String)

        !(group_number.valid_encoding? && group_number.encoding.ascii_compatible?)
      end

      # The lookup of set_field_value casts the group number before the row can refuse it. The method
      # raises the refusal of the row for a text that the cast cannot read.
      def refuse_unreadable_group_number!(slug, group_number)
        return unless unreadable_group_number?(group_number)

        new(custom_field_slug: slug, group_number: group_number).refuse_unreadable_group_number!
      end

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
    # The cast makes the Symbol of an unreadable text nil, which is no change on a row with no number.
    def group_number_given?
      new_record? || will_save_change_to_group_number? || group_number_unreadable?
    end

    # write_attribute left its Symbol in place of a text that the cast cannot read.
    def group_number_unreadable?
      group_number_before_type_cast == UNREADABLE_GROUP_NUMBER
    end

    # A number above the column range raises ActiveModel::RangeError at the save, and the integer cast
    # hides a boolean or a text ('abc' becomes 0). The check reads the group number as the caller gave
    # it. A nil group number passes: a caller can leave it unset.
    def reject_invalid_group_number
      given = group_number_before_type_cast
      return if given.nil? || storable_group_number?(given)

      errors.add(:base, group_number_refusal)
    end

    # An Integer or a text of ASCII digits. A Symbol can print as digits, and the cast makes it nil.
    # The digits check raises for a text that the cast cannot read. A write that skips write_attribute
    # can leave that text in the row.
    def storable_group_number?(given)
      return false unless given.is_a?(Integer) || given.is_a?(String)
      return false if self.class.unreadable_group_number?(given)

      given.to_s.match?(/\A\d+\z/) && given.to_i <= MAX_GROUP_NUMBER
    end

    # A missing translation must not hide the message. The process locale follows the language of the
    # admin or the site, and en.yml is the only file that carries each key. The message falls back to
    # English.
    def cama_rejection_message(key, **values)
      full_key = "camaleon_cms.admin.custom_field.message.#{key}"
      I18n.t(full_key, slug: custom_field_slug, **values,
                       default: I18n.t(full_key, slug: custom_field_slug, **values, locale: :en))
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
