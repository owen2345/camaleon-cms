# frozen_string_literal: true

module CamaleonCms
  module UploaderContentSecurity
    def svg_upload?(uploaded_io)
      file_path = if uploaded_io.is_a?(ActionDispatch::Http::UploadedFile)
                    uploaded_io.original_filename
                  else
                    uploaded_io.path
                  end
      file_path&.end_with?('.svg')
    end

    # Scans in-memory content. Callers holding decoded bytes (e.g. a base64 data:
    # payload) use this to check *before* writing to a web-served staging path, so
    # rejected content never reaches a servable location.
    #
    # Returns a truthy value (the matched pattern, or true for SVG) when unsafe,
    # nil when safe -- matching file_content_unsafe?'s contract.
    def content_unsafe?(content, filename: nil)
      return true if filename&.end_with?('.svg') && CamaleonCms::SvgContentChecker.unsafe?(content)
      return nil if filename&.end_with?('.svg')

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
  end
end
