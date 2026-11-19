# frozen_string_literal: true

module CamaleonCms
  # Save-time authorization gate for authored content that `do_shortcode` later expands (post
  # content, custom-field values, taxonomy/widget descriptions). A registered shortcode makes
  # theme/plugin code emit arbitrary HTML/JS at render, which the content scan cannot judge, so
  # authorship is GATED behind the default-off `content_shortcodes` manager permission rather than
  # filtered. The content is never escaped, stripped or rewritten -- a save carrying a shortcode is
  # refused for an untrusted author, and stored verbatim for a trusted one.
  #
  # Conforms to `security-capability-gating` (fail-closed) and the content-shortcode-gating
  # capability. A model gates an attribute with `gate_content_shortcodes :attr`; a newly added
  # surface that `do_shortcode` expands MUST adopt this gate (asserted by the coverage spec).
  module ContentShortcodeGate
    extend ActiveSupport::Concern

    class_methods do
      # Gate the named attribute(s) on create/update. The gate scans each attribute as stored and as
      # each renderer gives it to do_shortcode (cama_shortcode_texts). If a registered shortcode is
      # present and the actor is a non-administrator lacking `content_shortcodes`, the save is
      # refused with a base error.
      def gate_content_shortcodes(*attributes, on: %i[create update])
        gated = attributes.map(&:to_sym)
        validate(on: on) { cama_reject_unauthorized_shortcodes(gated) }
      end
    end

    private

    def cama_reject_unauthorized_shortcodes(attributes)
      return unless attributes.any? { |attr| cama_shortcode_attr_gated?(attr) }
      return if cama_trusted_for_shortcodes?

      errors.add(:base, cama_shortcode_rejection_message)
    end

    # The gate checks an attribute only when both of these are true:
    # - The attribute changed on this save, or the record is new. So an edit of the title only does
    #   not check the shortcode content that was stored before. Post#reject_untrusted_dangerous_content
    #   does the same.
    # - A text that a renderer gives to do_shortcode contains a registered shortcode.
    # A model that creates a row again for an unchanged value says so with cama_gate_unchanged?.
    #
    # The gate reads the value as it is, with no copy in UTF-8 (intended). On each Camaleon save, a
    # String in UTF-16 or with invalid bytes makes the model code raise an encoding error before the
    # gate, also for an administrator. Examples are NormalizeAttrs, String#squish and String#to_var.
    # So nothing is stored, and a request cannot send such a String: Rails answers with a 400.
    def cama_shortcode_attr_gated?(attr)
      return false unless new_record? || cama_gate_attribute_changed?(attr)
      return false if cama_gate_unchanged?(attr)

      value = self[attr]
      return false if value.blank?

      cama_shortcode_texts(attr, value.to_s).any? { |text| CamaleonCms::ShortcodeRegistry.content_has_shortcode?(text) }
    end

    # The texts that a renderer gives to do_shortcode: the stored text and each translation of it.
    # String#translate removes the translation marker of a later line, so a translation can join a
    # shortcode that the stored text does not contain. A model adds the texts that its own renderers
    # decode.
    def cama_shortcode_texts(_attr, text)
      cama_text_with_translations(text)
    end

    # The stored text and each text that String#translate shows. A text with no translation shows as
    # it is stored, so it is in the list once.
    def cama_text_with_translations(text)
      [text, *CamaleonCms::UnsafeMarkup.shown_texts(text)].uniq
    end

    # True when a new record holds a value that was already stored. False by default.
    def cama_gate_unchanged?(_attr)
      false
    end

    def cama_gate_attribute_changed?(attr)
      respond_to?("#{attr}_changed?") ? public_send("#{attr}_changed?") : attribute_changed?(attr.to_s)
    end

    # Fail closed (the gate applies) without a request context or on any evaluation error, per
    # security-capability-gating: a background job, rake task or console is untrusted. Administrators
    # always pass; a non-administrator passes only while holding the `content_shortcodes` manager
    # permission.
    def cama_trusted_for_shortcodes?
      user = CurrentRequest.user
      site = CurrentRequest.site
      return false if user.blank? || site.blank?
      return true if user.admin?

      CamaleonCms::Ability.new(user, site).can?(:manage, :content_shortcodes)
    rescue StandardError
      false
    end

    # Only en.yml carries this key while the process locale follows the current admin/site language
    # -- fall back to English rather than emit "translation missing".
    def cama_shortcode_rejection_message
      key = 'camaleon_cms.admin.shortcodes.message.rejected'
      I18n.t(key, default: I18n.t(key, locale: :en))
    end
  end
end
