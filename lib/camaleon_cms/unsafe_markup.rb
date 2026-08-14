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
  # The detector mirrors the gate cama_contact_form's admin controller applies to its authored
  # markup positions (keep the two in parity): parse once, compare what the safe-list scrubber
  # would remove against the parse's own reserialization, so only a genuine removal registers —
  # never a spelling difference (`Tom & Jerry`, `<br/>`, quote style, tag case). Three structural
  # guards cover what that comparison cannot see: markup the parser drops instead of scrubbing,
  # a tag left open at the end of the value, and a translation marker sitting inside a tag (the
  # renderer deletes markers, so one inside a tag splices markup the gate never saw).
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
      def unsafe_html?(value, tags:, attributes:)
        string = scannable_string(value)
        return false unless string.match?(SANITIZER_SIGNIFICANT)
        return true if string.bytesize > MAX_GATED_VALUE_BYTES
        return true if disallowed_comment?(string)
        return true if marker_inside_tag?(string)
        return true if unterminated_tag?(string)

        shielded = string.gsub(CamaleonRecord::TRANSLATION_TAG_HIDE_REGEX, CamaleonRecord::TRANSLATION_TAG_HIDE_MAP)
        fragment = parse(shielded)
        # The css scrubber reformats whitespace while it scrubs, so a benign `text-align: center`
        # would register as a removal in the comparison below. Check style values separately
        # (whitespace-insensitively) and normalize them on the tree first, so the comparison sees
        # identical css on both sides and only element/attribute removals register.
        return true if dangerous_or_normalized_css!(fragment)
        return true if attribute_holds_markup?(fragment)

        baseline = fragment.to_s
        return true if markup_dropped?(shielded, fragment)

        # One parse, not two: scrub the fragment already built, so both sides of the comparison
        # share the same parser and serializer and only a genuine removal differs.
        fragment.scrub!(scrubber_for(tags, attributes)).to_s != baseline
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

      private

      # Prefer the HTML5 parser (browser-parity) only when it is actually available: the method
      # arrived in loofah 2.21, so guard on the method itself, not on `Nokogiri::HTML5` (present
      # since nokogiri 1.11) -- an older loofah with a newer nokogiri would otherwise NoMethodError.
      def parse(string)
        if Loofah.respond_to?(:html5_fragment) && defined?(Nokogiri::HTML5)
          Loofah.html5_fragment(string)
        else
          Loofah.fragment(string)
        end
      end

      # The gate only reads, never stores. A legacy value with invalid (or non-UTF-8) encoding would
      # make the `match?` below raise ArgumentError -- a 500 on save and an abort of the scan task --
      # so scan a scrubbed UTF-8 copy instead. The stored bytes are never touched (reject, don't
      # transform), and invalid byte sequences cannot spell markup anyway.
      def scannable_string(value)
        string = value.to_s
        return string if string.encoding == Encoding::UTF_8 && string.valid_encoding?

        string.b.force_encoding(Encoding::UTF_8).scrub
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
      def dangerous_or_normalized_css!(fragment)
        fragment.css('[style]').any? do |node|
          original = node['style'].to_s
          scrubbed = Loofah::HTML5::Scrub.scrub_css(original)
          node['style'] = scrubbed
          css_declarations(original) != css_declarations(scrubbed)
        end
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
      def markup_dropped?(shielded, fragment)
        written = shielded.scan(START_TAG_NAME).flatten.map(&:downcase).tally
        return false if written.empty?

        parsed = fragment.css('*').map { |node| node.name.downcase }.tally
        written.any? { |name, count| parsed.fetch(name, 0) < count }
      end

      # An attribute value that decodes to a tag-open is markup smuggled through an attribute the
      # scrubber keeps -- a data-*/aria-* attribute admitted by shape, or an allowed one like `title`.
      # A client-side `data-html` sink (Bootstrap tooltip/popover, and similar) injects such a value
      # as HTML at render. Entity-encoded markup (`&lt;img ...&gt;`) leaves no literal `<` in the
      # stored bytes, so `markup_dropped?` never sees it; but the parser has already entity-decoded
      # the value on the node, so a tag-open here is real markup the renderer would emit. Reject it
      # (never rewrite). A legitimate `<` in an attribute value (rare) must be entity-escaped by hand.
      def attribute_holds_markup?(fragment)
        fragment.css('*').any? do |node|
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
          tags << match unless match.match?(/\A#{TRANSLATION_MARKER}\z/)
        end
        tags.match?(TRANSLATION_MARKER)
      end
    end
  end
end
