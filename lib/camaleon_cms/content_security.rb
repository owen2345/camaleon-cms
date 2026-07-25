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

    UNSAFE_EVENT_PATTERNS = %w[
      onabort onafter onbefore onbegin onblur oncanplay onchange onclick oncontextmenu oncopy oncuechange oncut
      ondblclick ondrag ondrop ondurationchange onend onended onerror onfocus onhashchange oninvalid oninput onkey
      onload onmessage onmouse ononline onoffline onpagehide onpageshow onpage onpaste onpause onplay onpopstate
      onprogress onpropertychange onratechange onreadystatechange onrepeat onreset onresize onscroll onsearch onseek
      onselect onshow onstalled onstorage onsubmit onsuspend ontimeupdate ontoggle onunload onvolumechange onwaiting
      onwheel
    ].map { |pattern| /#{pattern}\w*\s*=/i }.freeze

    # Elements able to navigate, exfiltrate, or load remote active content.
    # Longest-first so "frameset" is preferred over "frame".
    BLOCKED_ELEMENTS = %w[
      script iframe object embed base meta style form applet frameset frame link template portal marquee math
    ].freeze

    # "/" counts as a tag delimiter, so <script/src="..."> cannot evade the check.
    BLOCKED_ELEMENT_PATTERN = %r{</?(#{Regexp.union(BLOCKED_ELEMENTS).source})[\s/>]}i

    BLOCKED_SCHEMES = %w[javascript vbscript data].freeze

    # Allow whitespace between the characters of a scheme name: browsers strip it,
    # so "jav<TAB>ascript:" and "java<LF>script:" both execute.
    BLOCKED_SCHEME_PATTERN = Regexp.new(
      "(?:#{BLOCKED_SCHEMES.map { |s| s.chars.map { |c| Regexp.escape(c) }.join('\s*') }.join('|')})\\s*:",
      Regexp::IGNORECASE
    )

    SUSPICIOUS_PATTERNS = (UNSAFE_EVENT_PATTERNS + [
      BLOCKED_ELEMENT_PATTERN,
      BLOCKED_SCHEME_PATTERN
    ]).freeze

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
