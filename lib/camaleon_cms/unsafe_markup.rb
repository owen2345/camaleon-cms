# frozen_string_literal: true

require 'loofah'
require 'rails-html-sanitizer'

module CamaleonCms
  # Scan-and-reject gate for authored rich text (audit findings M17 and the post-content policy).
  #
  # The security model is rejection, not transformation: an untrusted author's content is either
  # stored exactly as written or refused with an error naming the problem — it is never silently
  # rewritten. Stored content therefore always equals authored content, and the frontend may render
  # it verbatim, which is what the templates do (`raw` post content, `raw` editor field values).
  #
  # The admin controller of cama_contact_form calls this detector for its authored markup positions
  # too. The detector parses once and compares what the safe-list scrubber would remove against the
  # parse's own reserialization, so only a genuine removal registers —
  # never a spelling difference (`Tom & Jerry`, `<br/>`, quote style, tag case). Three structural
  # guards cover what that comparison cannot see: markup the parser drops instead of scrubbing,
  # a tag left open at the end of the value, and a translation marker sitting inside a tag (the
  # renderer deletes markers, so one inside a tag splices markup the gate never saw). The scan also
  # reads each translation of the value, which is the text that the page shows.
  module UnsafeMarkup
    # Every gated value costs a parse, and both the number of values and their size are chosen by
    # the caller — bound the size so a pathological multi-megabyte value cannot drive a giant Loofah
    # parse. The ceiling is generous (an ordinary long article is well under it); callers surface an
    # over-size refusal with its own message via `too_large?`, and `unsafe_html?` keeps the check as a
    # fail-closed backstop for callers that do not pre-check.
    MAX_GATED_VALUE_BYTES = 2 * 1024 * 1024

    # Nothing below can find anything in a string holding none of these: the scrubber and the
    # serializer are both the identity function on it. `&` counts because entity decoding is a
    # rewrite, the private-use sentinels count because the translation-marker shield deletes any
    # supplied raw, and the control characters count because the HTML parser rewrites them.
    SANITIZER_SIGNIFICANT = /[<>&\u{E000}\u{E001}\u0000-\u0008\u000B\u000C\u000E-\u001F\u{FFFE}\u{FFFF}]/

    # A well-formed translation marker (`<!--:-->`, `<!--:en-->`). Any other `<!--` is refused:
    # the sanitizer strips comments, so a stray comment would register as a removal anyway, but an
    # unterminated one additionally swallows everything to the next `-->` when emitted.
    TRANSLATION_MARKER = /<!--:[\w|-]{0,5}-->/
    TRANSLATION_MARKER_ONLY = /\A#{TRANSLATION_MARKER}\z/
    private_constant :TRANSLATION_MARKER_ONLY

    # `<` only opens a tag when a name, a solidus or a markup declaration follows it — this is what
    # keeps `Age < 18` and `5 > 3` out of the tag scanners below.
    TAG_OPEN = %r{<[a-zA-Z/!?]}
    START_TAG_NAME = %r{<([a-zA-Z][a-zA-Z0-9]*)(?=[\s/>]|\z)}
    # One whole tag, quoted attribute values included, so a `>` inside an attribute does not look
    # like the end of the tag; an unterminated quote runs to the end of the value.
    TAG_SPAN = %r{<[a-zA-Z/!?][^"'>]*(?:(?:"[^"]*"?|'[^']*'?)[^"'>]*)*>?}

    # `data-*`/`aria-*` are admitted by shape: the set is open, they carry no behaviour of their
    # own (a data- attribute is inert without script; an aria- attribute only annotates), and
    # without them ordinary pasted Bootstrap-style markup would be refused for attributes no
    # rejection message names.
    OPEN_ATTR_NAME = /\A(?:data|aria)-[a-zA-Z][-a-zA-Z0-9_.]*\z/

    # A character that ends an HTML attribute value. A URL can encode each of them (%22 for `"`, %27 for `'`).
    URL_ATTRIBUTE_END = /["'<>`]/
    # The whitespace that ends an attribute value with no quotes, as the HTML parser reads it.
    HTML_WHITESPACE = /[\t\n\f\r ]/

    # rails-html-sanitizer >= 1.6 exposes the scrubber under Rails::HTML (all caps); older releases
    # (valid with Rails 6.1/7.0, which this gem supports) expose only Rails::Html. Resolve whichever
    # the host bundled so the engine loads across the whole supported range.
    PERMIT_SCRUBBER_BASE = defined?(Rails::HTML::PermitScrubber) ? Rails::HTML::PermitScrubber : Rails::Html::PermitScrubber

    class PermissiveDataAttrScrubber < PERMIT_SCRUBBER_BASE
      private

      def scrub_attribute?(name)
        return false if name.to_s.match?(OPEN_ATTR_NAME)

        super
      end
    end

    class << self
      # True when `value` contains markup outside the given allowlist (or one of the structural
      # shapes above). Callers reject the save when this is true for an untrusted author.
      #
      # The page shows String#translate of the value. translate removes the first marker of the
      # locale on each line, anywhere in the line. So a `<` right before such a marker forms a tag
      # with the text after the marker. The scan reads the stored text and each translation.
      def unsafe_html?(value, tags:, attributes:)
        string = scannable_string(value)
        return false unless string.match?(SANITIZER_SIGNIFICANT)
        return true if string.bytesize > MAX_GATED_VALUE_BYTES

        texts = [string]
        # A value with no marker has no translation, so the copy and the split are not necessary.
        texts.concat(String.new(string).translations.values) if string.include?('<!--:')
        texts.uniq.any? { |text| unsafe_text?(text, tags, attributes) }
      end

      # True when the value exceeds the parse-cost ceiling. Callers refuse it with a size-specific
      # message rather than the markup message — an over-size value may be perfectly clean.
      def too_large?(value)
        value.to_s.bytesize > MAX_GATED_VALUE_BYTES
      end

      # True when `value` carries a script-capable URI scheme (javascript:, vbscript:, or a
      # non-raster data: URI), tolerant of the gap characters and entity encodings a browser
      # strips. For values a renderer emits into a URL position (href/src).
      def dangerous_uri?(value)
        CamaleonCms::ContentSecurity.blocked_scheme?(value.to_s)
      end

      # True when a URL value holds a character that ends an HTML attribute: a quote, an angle
      # bracket, a backtick, or whitespace before another character. A page can put the value
      # inside a tag, as in <img src="[data field='photo']">. Without quotes, as in
      # <img src=https://cdn.test/[data field='photo']>, whitespace ends the value, and the characters
      # after it become a new attribute. So leading whitespace is refused too. Whitespace at the end
      # passes: no character of the value follows it.
      # A translated value holds the translation markers that the admin form writes. The data shortcode
      # shows one translation, without the markers that separate the translations. So those markers
      # pass, and both rules read each text that String#translate shows. translate removes only the
      # first marker of the locale on each line, so a shown text can keep a marker. A value with no
      # translation keeps each marker.
      # The check reads the value as unsafe_html? does, so a value in another encoding gets a verdict.
      def attribute_ending_url?(value)
        string = scannable_string(value)
        string.gsub(TRANSLATION_MARKER, '').match?(URL_ATTRIBUTE_END) ||
          string.dup.translations_array.any? do |url|
            url.match?(URL_ATTRIBUTE_END) || url.rstrip.match?(HTML_WHITESPACE)
          end
      end

      # The gate only reads, never stores. A value in another encoding, or with invalid bytes, makes
      # a `match?` of the scan raise ArgumentError -- a 500 on save and an abort of the scan task --
      # so the scan reads a UTF-8 copy. A database stores a valid String in another encoding, such
      # as UTF-16, as UTF-8 text, so the copy converts it. Any other value is read as scrubbed bytes:
      # invalid byte sequences cannot spell markup. The stored bytes are never touched (reject, don't
      # transform).
      def scannable_string(value)
        string = value.to_s
        return string if string.encoding == Encoding::UTF_8 && string.valid_encoding?

        utf8_copy(string) || string.b.force_encoding(Encoding::UTF_8).scrub
      end

      private

      # The checks of unsafe_html? for one text: the stored value or one translation of it.
      def unsafe_text?(string, tags, attributes)
        return false unless string.match?(SANITIZER_SIGNIFICANT)
        return true if disallowed_comment?(string)
        return true if marker_inside_tag?(string)
        return true if unterminated_tag?(string)

        shielded = string.gsub(CamaleonRecord::TRANSLATION_TAG_HIDE_REGEX, CamaleonRecord::TRANSLATION_TAG_HIDE_MAP)
        fragment = parse(shielded)
        return true if fragment.nil?

        # The checks below change only attribute values, so one list of the elements serves all three.
        nodes = elements(fragment)
        # The css scrubber reformats whitespace while it scrubs, so a benign `text-align: center`
        # would register as a removal in the comparison below. Check style values separately
        # (whitespace-insensitively) and normalize them on the tree first, so the comparison sees
        # identical css on both sides and only element/attribute removals register.
        return true if dangerous_or_normalized_css!(nodes)
        return true if attribute_holds_markup?(nodes)

        baseline = fragment.to_s
        return true if markup_dropped?(shielded, nodes)

        # One parse, not two: scrub the fragment already built, so both sides of the comparison
        # share the same parser and serializer and only a genuine removal differs.
        fragment.scrub!(scrubber_for(tags, attributes)).to_s != baseline
      end

      # Prefer the HTML5 parser (browser-parity) only when it is actually available: the method
      # arrived in loofah 2.21, so guard on the method itself, not on `Nokogiri::HTML5` (present
      # since nokogiri 1.11) -- an older loofah with a newer nokogiri would otherwise NoMethodError.
      # The HTML5 parser raises ArgumentError past its limits: more than 400 nested elements, or
      # more than 400 attributes on one element. The gate cannot scan such a value, so parse gives
      # nil and the caller refuses the value.
      def parse(string)
        if Loofah.respond_to?(:html5_fragment) && defined?(Nokogiri::HTML5)
          Loofah.html5_fragment(string)
        else
          Loofah.fragment(string)
        end
      rescue ArgumentError
        nil
      end

      # The UTF-8 copy of a valid String in another encoding, or nil when Ruby cannot convert it
      # (UTF-7). A binary String keeps its bytes, which are often UTF-8 already.
      def utf8_copy(string)
        return if string.encoding == Encoding::BINARY || !string.valid_encoding?

        string.encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
      rescue EncodingError
        nil
      end

      def scrubber_for(tags, attributes)
        PermissiveDataAttrScrubber.new.tap do |scrubber|
          scrubber.tags = tags
          scrubber.attributes = attributes
        end
      end

      # Scrub every style attribute with the same css scrubber the safe-list scrub uses, compare
      # declaration-by-declaration ignoring the scrubber's benign rewrites (whitespace, a trailing
      # semicolon), and write the scrubbed form back so the later serialization comparison cannot
      # re-register it. A surviving difference means the scrubber refused part of the css
      # (expression(), url(javascript:), a disallowed property) — dangerous, report it.
      def dangerous_or_normalized_css!(nodes)
        nodes.any? do |node|
          next false unless node.has_attribute?('style')

          original = node['style'].to_s
          scrubbed = Loofah::HTML5::Scrub.scrub_css(original)
          node['style'] = scrubbed
          css_declarations(original) != css_declarations(scrubbed)
        end
      end

      # Every element of the parse. Do not use `fragment.css`: a fragment runs the query once for
      # each top-level node and adds each result to the set so far, so its cost grows with the
      # square of the number of top-level nodes. A value with many translated blocks has many
      # top-level nodes (20,000 markers took about 27 s). This loop reads each element once and uses
      # no recursion, so a deep tree cannot exhaust the stack. Only an element contains elements,
      # so the loop reads no text or comment node.
      def elements(fragment)
        found = []
        pending = fragment.element_children.to_a
        until pending.empty?
          node = pending.pop
          found << node
          pending.concat(node.element_children.to_a)
        end
        found
      end

      def css_declarations(css)
        css.gsub(/\s+/, '').split(';').reject(&:empty?)
      end

      # Any `<!--` that is not a well-formed translation marker. A bare `-->` is ordinary text.
      def disallowed_comment?(string)
        string.gsub(TRANSLATION_MARKER, '').include?('<!--')
      end

      # A tag opened after the last `>` is never completed inside this value.
      def unterminated_tag?(string)
        string.rpartition('>').last.match?(TAG_OPEN)
      end

      # Every tag the author wrote has to appear in the parse. Compared by name rather than by
      # count, because the parser *inserts* elements too — an implied `<tbody>` would otherwise
      # cancel out a dropped `<td>` and let the pair through.
      def markup_dropped?(shielded, nodes)
        written = shielded.scan(START_TAG_NAME).flatten.map(&:downcase).tally
        return false if written.empty?

        parsed = nodes.map { |node| node.name.downcase }.tally
        written.any? { |name, count| parsed.fetch(name, 0) < count }
      end

      # An attribute value that decodes to a tag-open is markup smuggled through an attribute the
      # scrubber keeps -- a data-*/aria-* attribute admitted by shape, or an allowed one like `title`.
      # A client-side `data-html` sink (Bootstrap tooltip/popover, and similar) injects such a value
      # as HTML at render. Entity-encoded markup (`&lt;img ...&gt;`) leaves no literal `<` in the
      # stored bytes, so `markup_dropped?` never sees it; but the parser has already entity-decoded
      # the value on the node, so a tag-open here is real markup the renderer would emit. Reject it
      # (never rewrite). A legitimate `<` in an attribute value (rare) must be entity-escaped by hand.
      def attribute_holds_markup?(nodes)
        nodes.any? do |node|
          node.attribute_nodes.any? { |attr| attr.value.to_s.match?(TAG_OPEN) }
        end
      end

      # A translation marker separates whole translated blocks; it never belongs *inside* a tag.
      # The renderer deletes markers, so one inside a tag splices the halves into markup the
      # author never wrote and this gate never saw.
      def marker_inside_tag?(string)
        return false unless string.include?('<!--')

        tags = +''
        string.scan(/#{TRANSLATION_MARKER}|#{TAG_SPAN}/) do |match|
          tags << match unless match.match?(TRANSLATION_MARKER_ONLY)
        end
        tags.match?(TRANSLATION_MARKER)
      end
    end
  end
end
