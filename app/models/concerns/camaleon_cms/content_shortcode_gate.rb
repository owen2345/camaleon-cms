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
      # Gate the named attribute(s) on create/update. Each attribute is scanned in its RAW stored
      # form -- which contains every locale of a translatable value at once, so a shortcode in any
      # locale is caught -- and, if a registered shortcode is present and the actor is a
      # non-administrator lacking `content_shortcodes`, the save is refused with a base error.
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

    # An attribute needs the gate only when it (a) changed on this save (or the record is new) -- so
    # a title-only edit never re-gates pre-existing shortcode content, mirroring
    # Post#reject_untrusted_dangerous_content -- and (b) actually contains a registered shortcode.
    def cama_shortcode_attr_gated?(attr)
      return false unless new_record? || cama_gate_attribute_changed?(attr)

      value = self[attr]
      value.present? && CamaleonCms::ShortcodeRegistry.content_has_shortcode?(value.to_s)
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
