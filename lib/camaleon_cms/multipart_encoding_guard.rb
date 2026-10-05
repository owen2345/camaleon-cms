# frozen_string_literal: true

module CamaleonCms
  # Rack gives the name of a multipart part the charset of that part. For a charset that is not
  # ASCII-compatible (UTF-16), the param parser of Rack then raises an encoding error. For a POST,
  # Rack::MethodOverride reads the params outside the exception handler of Rails, so the server
  # answered with a 500. A browser form sends no charset for a part.
  #
  # The guard reads the params of a multipart request before Rack::MethodOverride. Rack keeps the
  # result in the env, so Rack and Rails do not parse the body again. For an encoding error of the
  # parser, the guard answers with a 400. Each other error of the parser stays with Rack and Rails.
  #
  # Rack 2.2 raises that encoding error only when the bytes of the part name are valid in the charset.
  # For other bytes it raises a plain ArgumentError, which the guard answers with a 400 too.
  class MultipartEncodingGuard
    def initialize(app)
      @app = app
    end

    def call(env)
      return @app.call(env) unless unreadable_part?(env)

      # The request stops before Rack::TempfileReaper, so the guard removes the files of its uploads.
      env[Rack::RACK_TEMPFILES]&.each(&:close!)
      env[Rack::RACK_ERRORS]&.puts('A multipart part has an encoding that the param parser cannot read')
      [400, { 'content-type' => 'text/plain; charset=utf-8' }, ['Bad Request']]
    end

    private

    def unreadable_part?(env)
      request = Rack::Request.new(env)
      return false unless request.media_type.to_s.start_with?('multipart/')

      request.POST
      false
    rescue EncodingError
      true
    rescue ArgumentError => e
      invalid_part_name?(e)
    rescue StandardError
      false
    end

    # Rack 2.2 raises a plain ArgumentError when the bytes of a part name are not valid in the charset
    # of the part. The param errors of Rack are subclasses of ArgumentError. Rack and Rails handle
    # them, so they pass.
    def invalid_part_name?(error)
      error.instance_of?(ArgumentError) && error.message.start_with?('invalid byte sequence')
    end
  end
end
