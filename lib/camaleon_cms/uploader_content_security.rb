# frozen_string_literal: true

require 'zlib'
require 'stringio'

module CamaleonCms
  module UploaderContentSecurity
    # Extensions a browser parses as markup. These select the parse-based checker; everything else
    # keeps the generic pattern ruleset.
    #
    # The routing key is *how the stored file will be rendered*, not a literal `.svg` comparison.
    # The two are not the same thing, and the difference was the bug: identical bytes carrying an
    # `onpointerdown` attribute were refused as `x.svg` and stored as `x.html`, because only the
    # first name reached the checker that rejects handlers by shape.
    #
    # Deliberately narrow. Everything listed here is served as markup and therefore parsed as markup
    # by the browser; nothing else is added "just in case". Running a markup parser over content
    # that is not markup invents attributes that were never written -- `if a<b and on=1 then x` in a
    # .txt parses to a `b` element with an `on` attribute -- so a wider list would refuse ordinary
    # text files.
    MARKUP_EXTENSIONS = %w[svg svgz svg.gz html htm xhtml xht shtml xml xsl xslt].freeze

    # Of those, the ones that are not well-formed XML and need the HTML parser (see
    # SvgContentChecker: the two modes differ in whether a parse failure means anything).
    HTML_MODE_EXTENSIONS = %w[html htm shtml].freeze

    # Gzip-compressed markup. Compressed bytes are high-entropy: no pattern matches them and no
    # parser reads them, so scanning them as they arrive is not weak scanning, it is no scanning.
    COMPRESSED_MARKUP_EXTENSIONS = %w[svgz svg.gz].freeze

    # Executable script. Refused for untrusted uploaders rather than scanned, because no scan can
    # reach a verdict on JavaScript: it has no safe subset, every dangerous capability is reachable
    # through dynamic construction (`window['fet'+'ch']`), and legitimate uploaded script is
    # arbitrary script -- indistinguishable from a payload by any static rule. A scanner that cannot
    # decide has to fail closed, and a fail-closed scanner for these types is a permission gate.
    #
    # The gate is the existing `media_unfiltered_upload`, not a new permission. Its holders skip
    # scanning entirely, so they could already store these files; reusing it grants nothing new and
    # changes nothing for an install that has already granted it, whereas a new permission would
    # revoke the capability from those installs until they granted the second one too.
    SCRIPT_EXTENSIONS = %w[js mjs cjs wasm swf].freeze

    # Ceiling on decompressed markup. Compression is the one case where the upload size limit stops
    # bounding the work: a few-KB upload can expand to gigabytes, so the input limit says nothing
    # about the memory the scan will use. Generous for a real compressed image and far below
    # anything a bomb aims for; an upload that exceeds it is refused rather than expanded further.
    MAX_DECOMPRESSED_MARKUP_BYTES = 10 * 1024 * 1024
    # Whether the current uploader may skip the malicious-content scan. Mirrors
    # Post#trusted_for_unfiltered_html?: read the request context, fail closed (scan) when
    # either half is missing -- background jobs, rake tasks and the console have no request
    # user, and an upload from there must be scanned rather than exempted.
    #
    # Deliberately not memoized. The crop flow evaluates this twice, which costs two role-meta
    # lookups on an operation already doing file I/O; an ivar memo would have to be invalidated
    # whenever CurrentRequest changes, and the object it would hang on is sometimes a long-lived
    # plugin helper rather than a per-request controller.
    def cama_trusted_for_unfiltered_upload?
      user = CurrentRequest.user
      site = CurrentRequest.site
      return false if user.blank? || site.blank?

      CamaleonCms::Ability.new(user, site).can?(:manage, :media_unfiltered_upload)
    rescue StandardError
      # Ability#initialize dereferences the site and reads role metas for non-admin users;
      # malformed meta must fail closed instead of aborting the upload with a 500.
      false
    end

    def svg_upload?(uploaded_io)
      file_path = if uploaded_io.is_a?(ActionDispatch::Http::UploadedFile)
                    uploaded_io.original_filename
                  else
                    uploaded_io.path
                  end
      cama_svg_extension?(file_path)
    end

    # Scans in-memory content. Callers holding decoded bytes (e.g. a base64 data:
    # payload) use this to check *before* writing to a web-served staging path, so
    # rejected content never reaches a servable location.
    #
    # Returns a truthy value (the matched pattern, or true for SVG) when unsafe,
    # nil when safe -- matching file_content_unsafe?'s contract.
    def content_unsafe?(content, filename: nil)
      extension = cama_upload_extension(filename)

      # No permission check here. Every caller reaches this method only after
      # `cama_trusted_for_unfiltered_upload?` already answered false, so the uploader is known to be
      # untrusted; asking again would cost a second role-meta lookup and could disagree with the
      # check that already ran. It also means the fail-closed behaviour is inherited exactly --
      # no request user or no site means the scan runs, and the scan refuses these.
      if SCRIPT_EXTENSIONS.include?(extension)
        Rails.logger.info { 'Potentially malicious content found: executable script upload' }
        return 'script_upload'
      end

      if MARKUP_EXTENSIONS.include?(extension)
        return true if markup_unsafe?(content, extension)

        return nil
      end

      normalized = CamaleonCms::ContentSecurity.normalize(content)
      if CamaleonCms::ContentSecurity.blocked_scheme_in?(normalized)
        Rails.logger.info { 'Potentially malicious content found: blocked URI scheme' }
        return 'blocked_scheme'
      end
      CamaleonCms::ContentSecurity::SUSPICIOUS_PATTERNS.each do |pattern|
        next unless normalized&.match?(pattern)

        Rails.logger.info { "Potentially malicious content found: #{pattern.inspect}" }
        return pattern.inspect
      end
      nil
    end

    # IO-based entry point: reads the handle, rewinds it so downstream consumers
    # still see the full content, and delegates to content_unsafe?.
    def file_content_unsafe?(uploaded_io)
      file = uploaded_io.is_a?(ActionDispatch::Http::UploadedFile) ? uploaded_io.tempfile : uploaded_io
      filename = if uploaded_io.is_a?(ActionDispatch::Http::UploadedFile)
                   uploaded_io.original_filename
                 else
                   uploaded_io.path
                 end
      file.set_encoding(Encoding::BINARY) if !svg_upload?(uploaded_io) && file.respond_to?(:binmode) &&
                                             file.respond_to?(:set_encoding)
      content = file.read
      file.rewind if file.respond_to?(:rewind)

      content_unsafe?(content, filename: filename)
    end

    private

    # The extension that selects the ruleset, lowercased. Handles three shapes a naive
    # `File.extname` gets wrong, each of which was or would be a routing bypass:
    #   - a compound `.svg.gz`, which File.extname reports as `.gz`
    #   - a dotfile (`.svg`), which File.extname reports as having no extension at all
    #   - any case (`evil.SVG`), since the stored name keeps whatever case the client sent
    # A name with no extension yields '' and takes the generic ruleset.
    def cama_upload_extension(name)
      base = File.basename(name.to_s).downcase
      compound = COMPRESSED_MARKUP_EXTENSIONS.find { |ext| ext.include?('.') && base.end_with?(".#{ext}") }
      return compound if compound

      extension = File.extname(base).delete_prefix('.')
      return extension if extension.present?

      # A basename that is entirely an extension (`.svg`) routes on that name rather than falling
      # through to the generic ruleset -- fail closed, preserving the behaviour of the suffix check
      # this replaced.
      base.start_with?('.') ? base.delete_prefix('.') : ''
    end

    # Markup verdict: the byte-level scheme check, then the parser the browser would use.
    #
    # The scheme check is not redundant with the parse, and dropping it would have lost detection.
    # `normalize` strips the NUL and C0 bytes a URL parser ignores inside a scheme, so
    # `java\0script:` matches on the raw bytes; the HTML parser instead *truncates* the attribute at
    # the NUL, leaving `java` and nothing for a parse-based check to find. Bytes and tree disagree,
    # so both are consulted.
    #
    # The element and handler patterns are deliberately not run here — the parse supersedes them.
    # BANNED_TAGS already unions ContentSecurity::BLOCKED_ELEMENTS, and the `on*` shape match is
    # strictly stronger than the stem list. What the parse changes is a documented false positive:
    # a document that merely *shows* escaped markup (`&lt;script&gt;`) contains no script element,
    # renders as literal text in a browser, and is no longer refused for it.
    def markup_unsafe?(content, extension)
      scannable = cama_markup_scannable(content, extension)
      return true if scannable == :too_large

      return true if CamaleonCms::ContentSecurity.blocked_scheme?(scannable)

      CamaleonCms::SvgContentChecker.unsafe?(scannable, mode: cama_markup_parse_mode(extension))
    end

    # The bytes a browser will actually parse: the decompressed payload for a compressed markup
    # extension, the content itself otherwise.
    #
    # Bytes under a compressed extension that are not valid gzip fall back to being scanned as raw
    # markup rather than skipped. nginx's default mime map serves `.svgz` as `image/svg+xml`, so an
    # ungzipped file under that name still renders as SVG; skipping it would be the same
    # scanned-in-name-only hole the compression created.
    def cama_markup_scannable(content, extension)
      return content unless COMPRESSED_MARKUP_EXTENSIONS.include?(extension)

      cama_gunzip_bounded(content) || content
    end

    # Decompresses at most MAX_DECOMPRESSED_MARKUP_BYTES. Returns the payload, `:too_large` when it
    # exceeds the ceiling, or nil when the bytes are not gzip at all.
    #
    # Reads one byte past the ceiling rather than reading to EOF and measuring afterwards: a
    # GzipReader decompresses lazily, so a bomb is detected having materialized only the bound, not
    # the gigabytes behind it.
    def cama_gunzip_bounded(content)
      reader = Zlib::GzipReader.new(StringIO.new(content.to_s.b))
      begin
        decompressed = reader.read(MAX_DECOMPRESSED_MARKUP_BYTES + 1).to_s
      ensure
        reader.close
      end
      return :too_large if decompressed.bytesize > MAX_DECOMPRESSED_MARKUP_BYTES

      decompressed
    rescue Zlib::Error, EOFError
      # Not gzip, or a truncated stream whose footer will not verify. Either way the caller falls
      # back to scanning the raw bytes, which fails closed for anything that is not clean markup.
      nil
    end

    def cama_markup_parse_mode(extension)
      HTML_MODE_EXTENSIONS.include?(extension) ? :html : :xml
    end

    # Case-insensitive `.svg` test. Upload names arrive with whatever case the client sent
    # (`evil.SVG`); a case-sensitive check routed those past the SVG-specific scanner into the
    # weaker generic ruleset, so both entry points normalize the extension here. A name whose
    # basename is exactly `.svg` (a dotfile, which File.extname reports as having no extension)
    # is still treated as an SVG: the pre-hardening `end_with?` check matched it, and routing it
    # to the stricter parser fails closed.
    def cama_svg_extension?(name)
      base = File.basename(name.to_s)
      File.extname(base).casecmp?('.svg') || base.casecmp?('.svg')
    end
  end
end
