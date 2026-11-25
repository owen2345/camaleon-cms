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

    # The entity types whose value the DTD of the file holds. Each other type points to another
    # resource, which the checker cannot read.
    INTERNAL_ENTITY_TYPES = [
      Nokogiri::XML::EntityDecl::INTERNAL_GENERAL, Nokogiri::XML::EntityDecl::INTERNAL_PARAMETER
    ].freeze

    # The start of an attribute default that declares a namespace, such as
    # `<!ATTLIST svg xmlns:onix CDATA "urn:onix">`.
    NAMESPACE_DEFAULT = /\A<!ATTLIST\s+\S+\s+xmlns:/

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

      if mode != HTML_MODE && entity_declarations(doc).any?
        doc = expanded_document(content, doc)
        return true if doc.nil? # an entity that the checker cannot read or expand -- fail closed
      end
      return true if mode != HTML_MODE && dangerous_attribute_default?(doc)

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
    # non-UTF-8 encoding before the scheme match). The serialization also holds the text of each
    # CDATA section and the declarations of the DTD.
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

    # The entity declarations of the DTD in the file. The list holds the entities that a parameter
    # entity declares, because the parser adds them to the DTD when it reads the reference.
    def entity_declarations(doc)
      doc.internal_subset&.children.to_a.grep(Nokogiri::XML::EntityDecl)
    end

    # The document as a browser reads it, with each entity reference replaced by the entity value.
    # Without this parse, an entity reference stays one node, and no check sees the elements and
    # the attributes that the entity value holds. The parser decodes a character reference in an
    # entity value before it reads the value as markup. So `&#111;nerror` in an entity value becomes
    # an `onerror` attribute, which the byte patterns of the scan do not see.
    #
    # Returns nil for a file that the checker must refuse:
    #   - The file declares an entity that points to another resource (`SYSTEM` or `PUBLIC`). The
    #     checker cannot read that resource, and the `noent` option makes the parser read a local
    #     file that such an entity names. So the check runs before the parse.
    #   - The parser reports a fatal error. libxml2 reports one for an entity that refers to
    #     itself, and for entities that expand to more than its limit permits (an entity bomb).
    #     It stops at the limit, so the parse does not use the memory of the expanded text. Never
    #     add the `huge` option here: it removes the limit.
    def expanded_document(content, doc)
      return nil unless entity_declarations(doc).all? { |decl| INTERNAL_ENTITY_TYPES.include?(decl.entity_type) }

      expanded = Nokogiri::XML(content) { |config| config.strict.nonet.noent }
      expanded.root && expanded
    rescue Nokogiri::XML::SyntaxError
      nil
    end

    # A browser gives an element each attribute default that the DTD of the file declares for it.
    # So `<!ATTLIST svg onload CDATA "...">` puts an `onload` handler on the `svg` element, and no
    # tag of the file holds that attribute. The parser keeps a default out of the tree. Its
    # `dtdattr` option adds the defaults, but that option also loads the external DTD. So this
    # method reads the declarations. It applies the handler rule and the scheme rule of an
    # attribute to each default. A declaration with `#IMPLIED` or `#REQUIRED` has no default.
    #
    # The caller gives the expanded document when the file declares an entity, so a default holds
    # the value of each entity that it refers to.
    def dangerous_attribute_default?(doc)
      doc.internal_subset&.children.to_a.grep(Nokogiri::XML::AttributeDecl).any? do |declaration|
        next false if declaration.default.nil?

        handler_default?(declaration) || ContentSecurity.blocked_scheme?(declaration.default)
      end
    end

    # A default with the `xmlns` prefix declares a namespace, so it gives no handler: `xmlns:onix`
    # passes here, as it passes on a tag. `name` gives the name without its prefix, so the method
    # reads the prefix from the text of the declaration. It asks for that text in UTF-8, because
    # `to_s` gives the text in the encoding of the file.
    def handler_default?(declaration)
      declaration.name.downcase.start_with?('on') &&
        !declaration.to_xml(encoding: 'UTF-8').match?(NAMESPACE_DEFAULT)
    end

    private_class_method :dangerous_document?, :dangerous_serialization?, :parse_document, :entity_declarations,
                         :expanded_document, :dangerous_attribute_default?, :handler_default?
  end
end
