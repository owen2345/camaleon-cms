# frozen_string_literal: true

module CamaleonCms
  class MediaSecurityHeaders
    SVG_PATH_PATTERN = %r{\A/media/.*\.svg\z}

    def initialize(app)
      @app = app
    end

    def call(env)
      status, headers, body = @app.call(env)

      if env['REQUEST_METHOD'] == 'GET' && env['PATH_INFO']&.match?(SVG_PATH_PATTERN)
        headers['X-Content-Type-Options'] = 'nosniff'
        headers['Content-Security-Policy'] = "script-src 'none'"
      end

      [status, headers, body]
    end
  end
end
