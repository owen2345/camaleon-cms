# frozen_string_literal: true

module CamaleonCms
  class MediaSecurityHeaders
    # Case-insensitive: an `evil.SVG` is stored and served verbatim (get_file_format downcases
    # the extension), so a case-sensitive match left uppercase-extension SVGs served inline
    # without the protective headers.
    SVG_PATH_PATTERN = %r{\A/media/.*\.svg\z}i

    def initialize(app)
      @app = app
    end

    def call(env)
      status, headers, body = @app.call(env)

      if env['REQUEST_METHOD'] == 'GET' && env['PATH_INFO']&.match?(SVG_PATH_PATTERN)
        # Lowercase header keys: the Rack 3 SPEC requires them and Falcon/Rack::Lint reject
        # mixed case (Puma tolerated it, which hid this).
        headers['x-content-type-options'] = 'nosniff'
        headers['content-security-policy'] = "script-src 'none'"
      end

      [status, headers, body]
    end
  end
end
