# frozen_string_literal: true

module CamaleonCms
  # Process-wide, boot-time registry of shortcode NAMES. It exists so that save-time code can detect
  # shortcodes without a frontend request: the per-request `CurrentRequest.shortcodes` list is
  # populated by the active frontend theme's `front_before_load` hook and is therefore empty in the
  # admin save path, so the save-time gate consults this canonical set instead.
  #
  # Providers declare their shortcode names through the `register` DSL at boot. Declarations run with
  # NO request/site context, so a declaration MUST NOT touch `current_site`/`request` -- only the
  # names move here; the render-time handler stays in `shortcode_add`. Core declares its own bundled
  # names (see CORE_SHORTCODES); a theme/plugin gem declares its names from its own boot (an
  # initializer or engine), e.g. `CamaleonCms::ShortcodeRegistry.register('redirect')`.
  #
  # Detection mirrors the engine's `ShortCodeHelper#cama_reg_shortcode` regex shape, sourced from
  # this registry rather than `CurrentRequest`, so a name is a match only when followed by a space +
  # attributes or an immediate "]" -- bracketed prose that is not a registered name is never treated
  # as a shortcode.
  #
  # Fail-closed (design D4): an "unavailable" registry -- boot never completed registration -- treats
  # any non-blank content as gated, so a non-administrator is refused rather than let through on an
  # empty set. A legitimately empty registry (available, but no provider declared any name) is a
  # distinct, non-error state that gates nothing.
  class ShortcodeRegistry
    # Core-bundled shortcode names, declared through the DSL at boot. Mirrors the shortcodes that
    # `ShortCodeHelper#shortcodes_init` adds per request; the two are kept in sync by hand (unifying
    # the boot DSL with the render-time `shortcode_add` registration is a deliberate non-goal -- see
    # the gate-content-shortcodes design).
    CORE_SHORTCODES = %w[widget load_libraries asset data].freeze

    class << self
      # Boot-time DSL: declare one or more shortcode names. Request-independent, idempotent, and
      # order-independent. Blank names are ignored.
      def register(*names)
        names.flatten.each do |name|
          name = name.to_s.strip
          registered_names << name unless name.empty?
        end
        @regexp = nil
        self
      end

      # Mark the registry as successfully built at boot. Called once registration has completed; if
      # boot raises before this point the registry stays unavailable and detection fails closed.
      def mark_available!
        @available = true
        self
      end

      def available?
        @available == true
      end

      # Frozen snapshot of the registered names.
      def names
        registered_names.dup.freeze
      end

      # Whether `content` contains a registered shortcode. Fails closed when the registry is
      # unavailable (any non-blank content is treated as gated); a legitimately empty registry
      # matches nothing.
      def content_has_shortcode?(content)
        content = content.to_s
        return false if content.empty?
        return true unless available?

        matcher = regexp
        return false if matcher.nil?

        matcher.match?(content)
      end

      # Test-only: reset to the unavailable/empty baseline.
      def reset!
        @registered_names = nil
        @regexp = nil
        @available = false
        self
      end

      private

      def registered_names
        @registered_names ||= Set.new
      end

      # Mirrors ShortCodeHelper#cama_reg_shortcode: "(\\[(a|b)((\s)((?!\\]).)*|)\\])". In that source
      # the "\s" is a literal space (a double-quoted-string escape, not the regex whitespace class),
      # so a code matches only when followed by a literal space + attributes, or an immediate "]".
      # Names are regex-escaped and ordered longest-first so a name that is a prefix of another
      # (e.g. media / media_gallery) still matches its own token.
      def regexp
        return nil if registered_names.empty?

        @regexp ||= begin
          codes = registered_names.sort_by { |name| -name.length }.map { |name| Regexp.escape(name) }.join('|')
          Regexp.new("(\\[(#{codes})((\s)((?!\\]).)*|)\\])")
        end
      end
    end
  end
end
