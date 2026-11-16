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

    # The save scans the value of every field kind (scan-and-reject policy). The data shortcode puts
    # a value of any kind into the page as markup, so each value is held to the post-content
    # allowlist. A `field_attrs` value is JSON, so the scan reads its decoded members and keys. A URI kind
    # also goes into href and src, so it is held to the URI rule too. A shortcode inside a tag puts a
    # URI value into an attribute, so the scan also refuses a character that ends the attribute. The
    # role that puts a shortcode of another kind inside a tag chooses that position (intended).
    JSON_MARKUP_FIELD_KEYS = %w[field_attrs].freeze
    URI_FIELD_KEYS = %w[url image audio video file].freeze
    # The settings and custom_fields permissions give a role the trust of an administrator
    # (docs/security/permissions.md). So a holder of one of them is trusted for the values of an
    # owner that is not a post (owner_trust_abilities).
    ADMIN_TRUST_ABILITIES = [%i[manage settings], %i[manage custom_fields]].freeze
    # An author can add a repeatable field group (is_repeat) to a post several times. For example, a
    # "Slide" group holds an image and a caption, and the author adds it one time for each slide.
    # group_number is the index of the slide that a value belongs to: 0 for the first slide, 1 for
    # the second. The largest index is the largest 4-byte integer. PostgreSQL and MySQL store the
    # column in 4 bytes.
    MAX_GROUP_NUMBER = 2_147_483_647
    # The largest number of bytes in a group number String, one byte for each ASCII digit. Rails 8.1.4
    # casts only the first 16 bytes of a String to an Integer. So Rails can store a longer String as
    # another number than the validated one.
    MAX_GROUP_NUMBER_DIGITS = 16

    # The Rails integer type with one change. The integer cast of Rails raises ArgumentError for a
    # String in an invalid encoding. For a String in an encoding such as UTF-16, a lookup raises an
    # encoding error. This type returns nil for such a String.
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

    # The slugs that where(custom_field_slug: key) reads for a key, with no query. A loaded
    # custom_field_values association reads its rows with it. It follows the rules of where:
    # - A key reads the slug that slug_of gives it: 'note' for :note, '5' for 5, '2020-01-01' for a Date.
    # - A Range reads each slug from its first value to its last value. An infinite value
    #   (Float::INFINITY) is no bound. With no other bound, a Range from Infinity or to -Infinity
    #   reads no slug.
    # - A list or a Set reads nil as a row with no slug, and a Range as a Range. When one other item
    #   is left, it reads as a key of its own, so a list in a list reads its keys. Several other items
    #   read as slugs.
    class KeySlugs
      def initialize(key)
        @slugs = []
        @ranges = []
        add(key)
      end

      def include?(slug)
        @slugs.include?(slug) || @ranges.any? { |range| range.cover?(slug) }
      end

      private

      def add(key)
        case key
        when Array, Set then add_list(key.to_a)
        when Range then add_range(key)
        else @slugs << slug_of(key)
        end
      end

      def add_range(range)
        first = range_bound(range.begin)
        last = range_bound(range.end)
        return if first.nil? && last.nil? && (infinity(range.begin) == 1 || infinity(range.end) == -1)

        @ranges << Range.new(first, last, range.exclude_end?)
      end

      def range_bound(value)
        slug_of(value) unless infinity(value)
      end

      # 1 for Infinity, -1 for -Infinity, and nil for each other value.
      def infinity(value)
        value.infinite? if value.respond_to?(:infinite?)
      end

      def add_list(list)
        special, keys = list.partition { |item| item.nil? || item.is_a?(Range) }
        special.each { |item| add(item) }
        keys.size == 1 ? add(keys.first) : keys.each { |item| @slugs << slug_of(item) }
      end

      # The database compares the slug with the key as the type of the attribute gives it and the
      # connection quotes it: '2020-01-01' for a Date. The connection cannot quote some keys (a Hash),
      # and the database then raises an error. Such a key stays as it is, and no slug is equal to it.
      def slug_of(key)
        value = CustomFieldsRelationship.type_for_attribute('custom_field_slug').serialize(key)
        begin
          CustomFieldsRelationship.connection_pool.with_connection { |connection| connection.type_cast(value) }
        rescue TypeError, EncodingError
          value
        end
      end
    end

    validate :reject_untrusted_dangerous_value
    validate :reject_invalid_group_number, if: :validate_group_number?
    # update_attribute and save(validate: false) skip the validation, and they store NULL for a String
    # that the type cannot cast. This callback refuses such a String: save and update_attribute return
    # false, and save! raises ActiveRecord::RecordInvalid.
    before_save :raise_group_number_refusal, if: :group_number_unreadable?
    # Any custom-field value is expanded by do_shortcode at render (CustomFieldsConcern#the_field
    # and friends), regardless of field type, so gate a shortcode in ANY value behind
    # content_shortcodes.
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

    # set_field_values deletes the value rows and creates them again. It marks a new row whose slug and
    # value equal a stored row, so the markup gate and the content_shortcodes gate do not check an
    # unchanged value again. A reader plus a bang enabler and no writer, as unfiltered_value. The mark
    # is only for the marked value: a later change of the value removes it, and a copy (dup) does not
    # get it.
    def previously_stored
      @previously_stored_value == [value]
    end

    def previously_stored!
      @previously_stored_value = [value]
      self
    end

    # The error message of an invalid group number.
    def group_number_refusal
      cama_rejection_message('group_number_invalid', max: MAX_GROUP_NUMBER, digits: MAX_GROUP_NUMBER_DIGITS)
    end

    # Raises ActiveRecord::RecordInvalid for an invalid group number.
    # _cama_refuse_invalid_group_number! of CustomFieldsRead calls it on an unsaved record.
    def refuse_invalid_group_number!
      raise_group_number_refusal if group_number_refused?
    end

    # Rails copies (dup) each attribute after the type cast, which changes 'abc' to a valid 0. So this
    # method copies the group number before the cast, and the copy of an invalid record is invalid.
    #
    # A copy is a new record, and a new record is always validated. So the copy of a stored record
    # with a negative number from an earlier release is invalid (intended). The copy does not get the
    # mark of previously_stored!.
    def initialize_dup(other)
      super
      @previously_stored_value = nil
      self[:group_number] = other.group_number_before_type_cast
    end

    class << self
      # True for a group number that the record validation accepts: nil (no group number), or a number
      # that storable_group_number? accepts.
      def valid_group_number?(given)
        given.nil? || storable_group_number?(given)
      end

      # True for a group number that _cama_lookup_group_numbers of CustomFieldsRead reads: an
      # Integer in the 4-byte range, or a group number that valid_group_number? accepts. A stored
      # value can hold a negative number from an earlier release. The database finds no row with an
      # Integer outside that range, so a loaded association reads no value with it either.
      def lookup_group_number?(given)
        return given.between?(-MAX_GROUP_NUMBER - 1, MAX_GROUP_NUMBER) if given.is_a?(Integer)

        valid_group_number?(given)
      end

      # Why the save-time gate would refuse this value for the field type, or nil if it passes:
      # :too_large (over the parse ceiling), :html (disallowed markup), :uri (script-capable URL),
      # :url_characters (a URL with a character that ends an attribute).
      # Ignores author trust, so the validation (trust-gated) and the scan_content rake task (which
      # reports every stored row) share one dispatch and cannot drift.
      def gate_rejection_reason(field_key, value)
        return if value.blank?
        return :too_large if CamaleonCms::UnsafeMarkup.too_large?(value)

        key = field_key.to_s
        if JSON_MARKUP_FIELD_KEYS.include?(key)
          :html if json_member_values(value).any? { |member| markup_unsafe?(member) }
        elsif URI_FIELD_KEYS.include?(key) && CamaleonCms::UnsafeMarkup.dangerous_uri?(value)
          :uri
        elsif markup_unsafe?(value)
          :html
        elsif URI_FIELD_KEYS.include?(key) && CamaleonCms::UnsafeMarkup.attribute_ending_url?(value)
          :url_characters
        end
      end

      private

      # True for an Integer from 0 to MAX_GROUP_NUMBER, and for a String of 1 to MAX_GROUP_NUMBER_DIGITS
      # digits with such a number ('5'). Each other class is invalid. The encoding test comes before the
      # regexp, because the regexp raises an error for a String in an invalid encoding.
      def storable_group_number?(given)
        return given.between?(0, MAX_GROUP_NUMBER) if given.is_a?(Integer)
        return false unless given.is_a?(String) && given.bytesize <= MAX_GROUP_NUMBER_DIGITS
        return false if GroupNumberType.unreadable?(given)

        given.match?(/\A\d+\z/) && given.to_i <= MAX_GROUP_NUMBER
      end

      def markup_unsafe?(value)
        CamaleonCms::UnsafeMarkup.unsafe_html?(
          value, tags: CamaleonCms::Post::CONTENT_ALLOWED_TAGS,
                 attributes: CamaleonCms::Post::CONTENT_ALLOWED_ATTRIBUTES
        )
      end

      # A field_attrs value stores JSON whose string members render verbatim. Scan every DECODED
      # member and key (Hash, Array or nested), not the stored bytes: the Rails JSON encoder unicode-escapes
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
        when Hash then node.flat_map { |key, member| [key.to_s, *flatten_json_strings(member)] }
        when Array then node.flat_map { |member| flatten_json_strings(member) }
        else [node.to_s]
        end
      end
    end

    private

    # A value that an untrusted author may not write is refused, never rewritten. So a stored value
    # always equals the authored value. The dispatch is the class-level gate_rejection_reason, which
    # the scan_content rake task calls too.
    #
    # The scan comes before the trust check of a non-admin, because that check loads the role and
    # its metas for each value. Most values pass the scan, so most saves load no role. An admin
    # skips the scan, as before.
    def reject_untrusted_dangerous_value
      return if value.blank? || unfiltered_value || previously_stored
      return if request_admin?

      field_key = custom_field&.options&.[](:field_key).to_s
      reason = self.class.gate_rejection_reason(field_key, value)
      return unless reason
      return if author_trusted_for_unfiltered_value?

      errors.add(:base, cama_rejection_message(rejection_message_key(reason)))
    end

    # The content_shortcodes gate skips a value that set_field_values marks as already stored.
    def cama_gate_unchanged?(attr)
      attr == :value && previously_stored
    end

    # An admin in a request context. Without a user or a site, the gate applies to an admin too.
    def request_admin?
      CurrentRequest.site.present? && CurrentRequest.user.present? && CurrentRequest.user.admin?
    end

    def rejection_message_key(reason)
      case reason
      when :too_large then 'value_too_large'
      when :uri then 'value_rejected_uri'
      when :url_characters then 'value_rejected_url_characters'
      else 'value_rejected_html'
      end
    end

    # True for a new record, and for a stored record whose group number changes. So code can still
    # update a stored record that holds a negative number from an earlier release. Also true for a
    # String that the type cannot cast, because Rails sees no change from nil to it.
    def validate_group_number?
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
      !self.class.valid_group_number?(group_number_before_type_cast)
    end

    # The message in the current language, or in English when that language has no translation. Only
    # en.yml has the messages value_too_large, value_rejected_uri and value_rejected_html.
    #
    # The English default keeps its placeholders, so I18n fills in the slug one time. A slug can
    # hold the placeholder syntax of I18n, and a second interpolation then raises an error.
    def cama_rejection_message(key, **values)
      full_key = "camaleon_cms.admin.custom_field.message.#{key}"
      I18n.t(full_key, slug: cama_message_slug, **values, default: I18n.t(full_key, locale: :en))
    end

    # The slug of the field in UTF-8, for a message. I18n raises an encoding error when it puts a
    # slug in an encoding such as UTF-16 into a message. Ruby has no converter for some encodings
    # (UTF-7). The method then keeps the ASCII characters of the slug, and puts U+FFFD in place of
    # each other byte.
    def cama_message_slug
      slug = custom_field_slug.to_s
      slug.encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
    rescue EncodingError
      slug.b.encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
    end

    # The trust of a non-admin: reject_untrusted_dangerous_value lets an admin pass before this check.
    # A role is trusted through one of the abilities that owner_trust_abilities gives for the owner.
    # Fails closed (the gate applies) without a request context — benign values still pass the scan.
    def author_trusted_for_unfiltered_value?
      user = CurrentRequest.user
      site = CurrentRequest.site
      return false if user.blank? || site.blank?

      abilities = owner_trust_abilities(site)
      return false if abilities.empty?

      ability = CamaleonCms::Ability.new(user, site)
      abilities.any? { |args| ability.can?(*args) }
    end

    # The abilities that trust a role for the values of the owner. An empty list means that only an
    # admin is trusted:
    # - a post: post_content_unfiltered_html for its post type, the permission of the post body.
    # - the current site: the abilities of ADMIN_TRUST_ABILITIES.
    # - a theme of the current site: those abilities and theme_settings, the permission of the
    #   theme settings save.
    # - a site or a theme of another site, and a row with no owner: none.
    # - each other owner, such as a category or a post type: the abilities of ADMIN_TRUST_ABILITIES.
    def owner_trust_abilities(site)
      parent = owner
      case parent
      when nil then []
      when CamaleonCms::Post
        parent.post_type.present? ? [[:post_content_unfiltered_html, parent.post_type]] : []
      when CamaleonCms::Site
        parent.id == site.id ? ADMIN_TRUST_ABILITIES : []
      when CamaleonCms::Theme
        parent.parent_id == site.id ? ADMIN_TRUST_ABILITIES + [%i[manage theme_settings]] : []
      else ADMIN_TRUST_ABILITIES
      end
    end

    def set_parent_slug
      # self.update_column('custom_field_slug', self.custom_fields.slug)
    end

    # Touch the owner. owner resolves the scope name, so a widget value touches its widget.
    def update_model_owner
      owner&.touch # rubocop:disable Rails/SkipsModelValidations
    rescue StandardError
      nil
    end
  end
end
