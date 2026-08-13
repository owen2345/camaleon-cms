# frozen_string_literal: true

require 'cgi'

module CamaleonCms
  # SVG content security is now handled by CamaleonCms::SvgContentChecker
  # (Nokogiri XML parse-based detection). These patterns are retained for non-SVG file
  # scanning as a defense-in-depth layer.
  module ContentSecurity
    # Bounded like UserUrlValidator#validate_path_traversal, so multiply-encoded
    # payloads are caught without a decoding bomb looping forever.
    DECODE_PASSES = 5

    # NUL and C0 controls are stripped before matching: browsers ignore them inside
    # a URI scheme, so "java\0script:" is live markup while the raw bytes match
    # nothing. TAB/LF/CR are deliberately kept -- they are legitimate in text, and
    # the scheme patterns below tolerate them explicitly instead. The C1 range
    # (\x80-\x9f) is deliberately NOT stripped: those bytes are UTF-8 continuation
    # bytes, and removing them would mangle legitimate multibyte text.
    CONTROL_CHARS = /[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]/

    # Event-handler attribute stems. Each is matched as `<stem>\w*\s*=`, so a stem covers its
    # whole family (`onmouse` → onmousedown/onmouseover/...).
    UNSAFE_EVENT_HANDLERS = %w[
      onabort onafter onbefore onbegin onblur oncanplay onchange onclick oncontextmenu oncopy oncuechange oncut
      ondblclick ondrag ondrop ondurationchange onend onended onerror onfocus onhashchange oninvalid oninput onkey
      onload onmessage onmouse ononline onoffline onpagehide onpageshow onpage onpaste onpause onplay onpopstate
      onprogress onpropertychange onratechange onreadystatechange onrepeat onreset onresize onscroll onsearch onseek
      onselect onshow onstalled onstorage onsubmit onsuspend ontimeupdate ontoggle onunload onvolumechange onwaiting
      onwheel
    ].freeze

    # One alternation over all stems instead of 58 separate scans of the full buffer — the same
    # `<stem>\w*\s*=` match, folded into a single pass.
    UNSAFE_EVENT_PATTERN = /(?:#{Regexp.union(UNSAFE_EVENT_HANDLERS).source})\w*\s*=/i

    # Elements able to navigate, exfiltrate, or load remote active content.
    # Longest-first so "frameset" is preferred over "frame".
    BLOCKED_ELEMENTS = %w[
      script iframe object embed base meta style form applet frameset frame link template portal marquee math
    ].freeze

    # "/" counts as a tag delimiter, so <script/src="..."> cannot evade the check.
    BLOCKED_ELEMENT_PATTERN = %r{</?(#{Regexp.union(BLOCKED_ELEMENTS).source})[\s/>]}i

    # Script schemes are dangerous in any URI position.
    SCRIPT_SCHEMES = %w[javascript vbscript].freeze

    # A browser interprets a data: URI by its media type, so data:image/png;base64,... is an inert
    # bitmap (Inkscape/Figma embed rasters this way and such files must upload), while data:text/html
    # and data:image/svg+xml carry active content. These raster media types are therefore allowed;
    # every other data: URI is blocked.
    DATA_URI_SAFE_MEDIA = %w[
      image/png image/gif image/jpeg image/jpg image/webp image/bmp image/avif
      image/x-icon image/vnd.microsoft.icon
    ].freeze

    # Characters the URL parser strips from inside a scheme ("jav<TAB>ascript:" executes as
    # javascript:). blocked_scheme_in? deletes these before matching, so the pattern itself stays a
    # cheap contiguous alternation instead of an `[\t\n\r]*` between every character -- the latter
    # backtracked into seconds of CPU on adversarial near-miss input. Deliberately not all of \s: a
    # space is not stripped, so "Sample data : 42" stays prose, never a working URI.
    SCHEME_GAP_CHARS = "\t\n\r"

    # An allowlisted raster media type ending at a data-URI delimiter (;/,), a markup boundary
    # (whitespace/quote/>/)), or end of input -- so "image/pngx" is not mistaken for "image/png".
    DATA_URI_SAFE_MEDIA_PATTERN = /(?:#{Regexp.union(DATA_URI_SAFE_MEDIA).source})(?=[;,\s"'>)]|\z)/i

    # javascript:/vbscript: are always blocked. data: is blocked only when it is a functional data URI
    # -- a media type, or a bare ;/, delimiter -- that is NOT an allowlisted raster image; prose that
    # merely contains "...data:" has no such continuation and is left alone. Gaps are deleted by
    # blocked_scheme_in? before this matches, so the scheme and media type are written contiguously.
    BLOCKED_SCHEME_PATTERN = Regexp.new(
      "(?:#{Regexp.union(SCRIPT_SCHEMES).source}):" \
      "|data:(?!#{DATA_URI_SAFE_MEDIA_PATTERN.source})(?:[a-z0-9.+-]+/[a-z0-9.+-]+|[;,])",
      Regexp::IGNORECASE
    )

    SUSPICIOUS_PATTERNS = [
      UNSAFE_EVENT_PATTERN,
      BLOCKED_ELEMENT_PATTERN
    ].freeze

    # True if `content` carries a blocked URI scheme. Normalizes (entity/control-char decoding)
    # first -- use this when you hold raw bytes (the SVG scanner). The non-SVG ruleset normalizes
    # once for all its patterns and calls blocked_scheme_in? directly to avoid a second full copy.
    def self.blocked_scheme?(content)
      return false if content.nil?

      blocked_scheme_in?(normalize(content))
    end

    # Same test against already-normalized content. The gap bytes a browser strips inside a scheme
    # are removed here so BLOCKED_SCHEME_PATTERN can stay a cheap contiguous match rather than
    # backtracking through an `[\t\n\r]*` between every character.
    def self.blocked_scheme_in?(normalized)
      return false if normalized.nil?

      normalized.delete(SCHEME_GAP_CHARS).match?(BLOCKED_SCHEME_PATTERN)
    end

    # Canonicalizes content so encoded variants of a blocked pattern are detected.
    # Returns a normalized copy; the stored file is never modified.
    #
    # Deliberately entity-decoding only, NOT percent-decoding -- unlike
    # UserUrlValidator, which percent-decodes because its input is a URL that gets
    # parsed and resolved, where "%252e%252e" really does become "..". Here the input
    # is file content a browser parses as markup: "&#x61;" really does become "a" in
    # an attribute, but a percent-escape does not. Per the URL spec the scheme is
    # matched literally, so "%6Aavascript:" and "javascript%3Aalert(1)" are not
    # schemes at all and never execute. Percent-decoding here would buy no coverage
    # and would reject legitimate files that merely contain encoded URLs (JSON
    # exports, CSVs of links, access logs).
    def self.normalize(content)
      return content if content.nil?

      normalized = content.dup.force_encoding(Encoding::BINARY)
      normalized = decode_entities(normalized) if normalized.include?('&')
      normalized = normalized.gsub(CONTROL_CHARS, '') if CONTROL_CHARS.match?(normalized)
      normalized
    end

    # Repeatedly decodes HTML entities until stable, capped at DECODE_PASSES so a
    # deliberately deep chain cannot spin. Falls back to the last good value if a
    # decode produces bytes that cannot be handled.
    def self.decode_entities(content)
      DECODE_PASSES.times do
        decoded = CGI.unescapeHTML(content).force_encoding(Encoding::BINARY)
        break if decoded == content

        content = decoded
      end
      content
    rescue ArgumentError, Encoding::CompatibilityError
      content
    end
  end
end
