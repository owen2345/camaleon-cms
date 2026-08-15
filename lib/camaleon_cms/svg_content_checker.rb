# frozen_string_literal: true

module CamaleonCms
  # Parse-based rejection for uploads a browser parses as markup.
  #
  # Named for SVG because that is where it started; it now serves every markup extension the
  # scanner routes here (see UploaderContentSecurity::MARKUP_EXTENSIONS). The reason is the reason
  # it replaced the regex denylist for SVG: event handlers are rejected *by shape* — any attribute
  # whose name begins with `on` — so no handler name is ever enumerated, and a handler the web
  # platform ships next year is refused without a code change. A name list cannot make that promise;
  # the one in ContentSecurity is missing `onpointer*`, `ontouch*` and `onauxclick` today.
  module SvgContentChecker
    # `animate` and `set` are intentionally absent: SMIL animation elements carry no
    # script by themselves, and their scripting vector is the onbegin/onend/onrepeat
    # attribute, which the element-agnostic on* check below rejects wherever it appears.
    # foreignObject and handler stay banned — they embed foreign markup or handlers.
    #
    # form/meta/base/style/link are valid in SVG and none executes script on its own, but an
    # uploaded SVG is served inline from the site origin and these five are what turn a passive
    # image into markup that can navigate (meta http-equiv=refresh, base href), collect input
    # (form), or pull in remote styling (link, style). This list only ever runs for uploads that are
    # being scanned at all, i.e. from uploaders without `media_unfiltered_upload`, so it needs no
    # trust argument.
    SVG_BANNED_TAGS = %w[
      script foreignObject iframe object embed handler form meta base style link
    ].freeze

    # What the checker actually refuses: the SVG list above unioned with the generic ruleset's
    # element denylist. The union is load-bearing, not tidiness. ContentSecurity::BLOCKED_ELEMENTS
    # refuses `applet frameset frame template portal marquee math`, which SVG_BANNED_TAGS does not;
    # routing `.html` here while checking only the SVG list would have *narrowed* what an HTML
    # upload is refused for. Unioning means every extension routed here is refused for at least
    # everything the ruleset it came from refused.
    BANNED_TAGS = (SVG_BANNED_TAGS | ContentSecurity::BLOCKED_ELEMENTS).freeze

    # Extensions parsed as HTML rather than XML. Kept here rather than inferred, because the two
    # modes differ in what a parse failure means (see `parse_document`).
    HTML_MODE = :html
    XML_MODE = :xml

    # Lowercasing tables for XPath translate(). The tag check folds case so a name an HTML parser
    # lowercases is matched the same as its source form: `Nokogiri::HTML` reports `<foreignObject>`
    # as `foreignobject`, and an SVG inlined into an HTML document fires `<SCRIPT>` exactly as
    # `<script>`. Without folding, `foreignObject` -- the only mixed-case entry in BANNED_TAGS --
    # would be refused as `.svg` (XML, case-sensitive) yet accepted as `.html`.
    ASCII_UPPER = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    ASCII_LOWER = 'abcdefghijklmnopqrstuvwxyz'

    # The banned-element XPath, built once from the frozen BANNED_TAGS rather than reassembled on
    # every scan: `//*[translate(local-name(),UPPER,LOWER)='tag' or ...]`, each tag folded to
    # lowercase so an HTML-lowercased element name still matches.
    BANNED_TAGS_XPATH = "//*[#{BANNED_TAGS.map do |tag|
      "translate(local-name(), '#{ASCII_UPPER}', '#{ASCII_LOWER}') = '#{tag.downcase}'"
    end.join(' or ')}]".freeze

    module_function

    # `mode:` defaults to :xml so the pre-existing single-argument call (`unsafe?(content)`) keeps
    # its exact behaviour for any downstream caller.
    def unsafe?(content, mode: XML_MODE)
      return true if content.nil? || content.empty? # rubocop:disable Rails/Blank

      doc = parse_document(content, mode)
      return true if doc.nil? # XML syntax error -- fail closed

      # XML mode only. A document that parses to nothing is not a valid document of its format, so
      # refusing it fails closed. HTML has no such signal — Nokogiri::HTML never raises and reports
      # a nil root for input as ordinary as a whitespace-only or comment-only file, which must be
      # accepted. See design.md D3: the guarantee does not exist in HTML mode and is not faked.
      return true if mode != HTML_MODE && doc.root.nil?

      dangerous_document?(doc, mode)
    end

    def dangerous_document?(doc, mode)
      return true if doc.xpath(BANNED_TAGS_XPATH).any?

      # Case-insensitive: XML attribute names are case-sensitive, but an SVG inlined into an HTML
      # document fires ONCLICK/OnClick exactly as onclick, and the non-SVG ruleset already matches
      # handlers case-insensitively. translate() lowercases the "on" prefix so every case variant is
      # caught (no standard attribute name in either format begins with "on" except an event
      # handler). This is the shape match that makes the handler *name* irrelevant.
      return true if doc.xpath('//@*[starts-with(translate(local-name(), "ON", "on"), "on")]').any?

      # Blocked URI schemes via the shared ContentSecurity.blocked_scheme?, so the markup and generic
      # rulesets cannot drift apart about the same bytes (audit 2026-08-11 NEW-1). Nokogiri decodes
      # char-refs into attr.value but re-emits them in serialization, so the href is matched decoded
      # while the serialized document is entity-decoded (normalized) inside the helper before the
      # scheme match.
      return true if doc.xpath('//@*[local-name() = "href"]').any? do |attr|
        ContentSecurity.blocked_scheme?(attr.value)
      end

      dangerous_serialization?(doc, mode)
    end

    # Serialization echoes the document's declared encoding, so a UTF-16/UTF-32 document yields an
    # ASCII-incompatible String. Matching an ASCII regex against it raises
    # Encoding::CompatibilityError, which the rescue below does not catch -- surfacing as a 500
    # on upload instead of a verdict. Force BINARY first: the byte scan stays correct (BANNED_TAGS
    # already caught any <script> element, and normalize strips the interleaved NUL bytes of a
    # non-UTF-8 encoding before the scheme match). Catches DTD entity declarations and CDATA
    # sections, whose expansion is only visible after the parse.
    def dangerous_serialization?(doc, mode)
      serialized = (mode == HTML_MODE ? doc.to_html : doc.to_xml).b
      return true if serialized.match?(/<script[\s>]/i)

      ContentSecurity.blocked_scheme?(serialized)
    end

    # The rescue is confined to XML mode on purpose: Nokogiri::HTML never raises, so a shared rescue
    # would be dead code implying a fail-closed guarantee that HTML mode cannot provide.
    def parse_document(content, mode)
      return Nokogiri::HTML(content) if mode == HTML_MODE

      Nokogiri::XML(content, &:nonet)
    rescue Nokogiri::XML::SyntaxError
      nil
    end

    private_class_method :dangerous_document?, :dangerous_serialization?, :parse_document
  end
end
