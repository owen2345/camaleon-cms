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

    # Two escape sequences of ISO-2022-JP, `ESC ( B` and `ESC ( J`. A browser removes them from a
    # file in that encoding, and it still reads the characters of a scheme after them. So the bytes
    # `&col\e(Bon;` are `&colon;` in the page.
    ISO_2022_JP_ESCAPES = /\e\([BJ]/

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

    # The HTML named character references for the characters that a match of
    # BLOCKED_SCHEME_PATTERN holds, other than a letter or a digit, and for the TAB and the LF of
    # SCHEME_GAP_CHARS. `CGI.unescapeHTML` does not decode them. A browser reads them in an HTML
    # file, and in an XML file with a public XHTML DOCTYPE, so `href="javascript&colon;alert(1)"`
    # is a script link there. Each name is case-sensitive and needs its semicolon.
    NAMED_REFERENCES = {
      '&colon;' => ':', '&Tab;' => "\t", '&NewLine;' => "\n", '&sol;' => '/', '&semi;' => ';', '&comma;' => ',',
      '&period;' => '.', '&plus;' => '+'
    }.freeze
    NAMED_REFERENCE_PATTERN = Regexp.union(NAMED_REFERENCES.keys)

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

    # Byte-level backstop for markup, immune to the encoding a parser autodetects. A markup parser
    # picks its encoding from in-band signals (a BOM, an XML declaration, a `<meta charset>`) that a
    # browser can resolve differently -- WHATWG maps a `utf-16`/`utf-32` `<meta charset>` back to
    # UTF-8, so a pure-ASCII document declaring utf-16 fires its handlers in the browser while the
    # parser re-decodes the bytes as utf-16 and sees none. Stripping the NUL/C0 padding collapses a
    # UTF-16/UTF-32 (or spoofed-declaration) handler down to the ASCII bytes the browser will run,
    # so the element and handler patterns match it regardless of the declared encoding.
    #
    # Deliberately does NOT entity-decode, unlike `normalize`: character references in a tag or
    # attribute NAME are never decoded by a browser (`on&#99;lick` is an inert attribute, not
    # `onclick`), so decoding would buy no coverage while turning escaped markup (`&lt;script&gt;`,
    # which a browser renders as text) into a false positive. The scheme check keeps using
    # `blocked_scheme?`, which does normalize, because a scheme in an attribute VALUE is decoded.
    def self.suspicious_markup_bytes?(content)
      return false if content.nil?

      stripped = content.dup.force_encoding(Encoding::BINARY).gsub(CONTROL_CHARS, '')
      UNSAFE_EVENT_PATTERN.match?(stripped) || BLOCKED_ELEMENT_PATTERN.match?(stripped)
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

      # The first strip removes the NUL padding of a UTF-16 or UTF-32 file, so the decode reads the
      # references of such a file. ISO_2022_JP_ESCAPES go before it for the same reason: the strip
      # removes only their ESC byte. The second strip removes a control character that a reference
      # gives.
      normalized = content.dup.force_encoding(Encoding::BINARY)
      normalized = normalized.gsub(ISO_2022_JP_ESCAPES, '') if normalized.include?("\e")
      normalized = strip_control_chars(normalized)
      return normalized unless normalized.include?('&')

      strip_control_chars(decode_entities(normalized))
    end

    def self.strip_control_chars(content)
      CONTROL_CHARS.match?(content) ? content.gsub(CONTROL_CHARS, '') : content
    end
    private_class_method :strip_control_chars

    # Repeatedly decodes HTML entities until stable, capped at DECODE_PASSES so a
    # deliberately deep chain cannot spin. Falls back to the last good value if a
    # decode produces bytes that cannot be handled. Each pass also decodes NAMED_REFERENCES.
    def self.decode_entities(content)
      DECODE_PASSES.times do
        decoded = CGI.unescapeHTML(content).force_encoding(Encoding::BINARY)
        decoded = decoded.gsub(NAMED_REFERENCE_PATTERN, NAMED_REFERENCES)
        break if decoded == content

        content = decoded
      end
      content
    rescue ArgumentError, Encoding::CompatibilityError
      content
    end
  end
end
