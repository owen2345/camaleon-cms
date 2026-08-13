# frozen_string_literal: true

module CamaleonCms
  module SvgContentChecker
    # `animate` and `set` are intentionally absent: SMIL animation elements carry no
    # script by themselves, and their scripting vector is the onbegin/onend/onrepeat
    # attribute, which the element-agnostic on* check below rejects wherever it appears.
    # foreignObject and handler stay banned — they embed foreign markup or handlers.
    #
    # form/meta/base/style/link are valid in SVG and none executes script on its own, but an
    # uploaded SVG is served inline from the site origin and these five are what turn a passive
    # image into markup that can navigate (meta http-equiv=refresh, base href), collect input
    # (form), or pull in remote styling (link, style). ContentSecurity::BLOCKED_ELEMENTS already
    # refuses all five in every non-SVG upload; refusing them here too means the two rulesets stop
    # disagreeing about the same bytes, so re-uploading a file under a different extension cannot
    # reach a more permissive ruleset. This list only ever runs for uploads that are being scanned
    # at all, i.e. from uploaders without `media_unfiltered_upload`, so it needs no trust argument.
    BANNED_TAGS = %w[
      script foreignObject iframe object embed handler form meta base style link
    ].freeze

    module_function

    def unsafe?(svg_content)
      return true if svg_content.nil? || svg_content.empty? # rubocop:disable Rails/Blank

      doc = Nokogiri::XML(svg_content, &:nonet)
      return true unless doc.root

      banned_tags_query = BANNED_TAGS.map { |tag| "local-name() = '#{tag}'" }.join(' or ')
      return true if doc.xpath("//*[#{banned_tags_query}]").any?

      # Case-insensitive: XML attribute names are case-sensitive, but an SVG inlined into an HTML
      # document fires ONCLICK/OnClick exactly as onclick, and the non-SVG ruleset already matches
      # handlers case-insensitively. translate() lowercases the "on" prefix so every case variant is
      # caught (no standard SVG attribute name begins with "on" except an event handler).
      return true if doc.xpath('//@*[starts-with(translate(local-name(), "ON", "on"), "on")]').any?

      # Blocked URI schemes via the shared ContentSecurity.blocked_scheme?, so the SVG and non-SVG
      # rulesets cannot drift apart about the same bytes (audit 2026-08-11 NEW-1). Nokogiri decodes
      # char-refs into attr.value but re-emits them in to_xml, so the href is matched decoded while the
      # serialized document is entity-decoded (normalized) inside the helper before the scheme match.
      return true if doc.xpath('//@*[local-name() = "href"]').any? do |attr|
        ContentSecurity.blocked_scheme?(attr.value)
      end

      # to_xml echoes the document's declared encoding, so a UTF-16/UTF-32 SVG yields an
      # ASCII-incompatible String. Matching an ASCII regex against it raises
      # Encoding::CompatibilityError, which the rescue below does not catch -- surfacing as a 500
      # on upload instead of a verdict. Force BINARY first: the byte scan stays correct (BANNED_TAGS
      # already caught any <script> element, and normalize strips the interleaved NUL bytes of a
      # non-UTF-8 encoding before the scheme match).
      serialized = doc.to_xml.b
      return true if serialized.match?(/<script[\s>]/i)
      return true if ContentSecurity.blocked_scheme?(serialized)

      false
    rescue Nokogiri::XML::SyntaxError
      true
    end
  end
end
