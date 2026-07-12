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

    def file_content_unsafe?(uploaded_io)
      file = uploaded_io.is_a?(ActionDispatch::Http::UploadedFile) ? uploaded_io.tempfile : uploaded_io
      if svg_upload?(uploaded_io)
        content = file.read
        file.rewind if file.respond_to?(:rewind)
        return true if CamaleonCms::SvgContentChecker.unsafe?(content)

        return nil
      end

      file_content_unsafe = nil
      file.set_encoding(Encoding::BINARY) if file.respond_to?(:binmode) && file.respond_to?(:set_encoding)
      file_content = file.read
      file.rewind if file.respond_to?(:rewind)
      CamaleonCms::ContentSecurity::SUSPICIOUS_PATTERNS.each do |pattern|
        if file_content&.match?(pattern)
          Rails.logger.info { "Potentially malicious content found: #{pattern.inspect}" }
          break file_content_unsafe = pattern.inspect
        end
      end
      file_content_unsafe
    end
  end
end
