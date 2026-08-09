# frozen_string_literal: true

module CamaleonCms
  module UploaderContentSecurity
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
      if cama_svg_extension?(filename)
        return true if CamaleonCms::SvgContentChecker.unsafe?(content)

        return nil
      end

      normalized = CamaleonCms::ContentSecurity.normalize(content)
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
