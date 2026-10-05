# frozen_string_literal: true

module CamaleonCms
  # Answers a multipart request with a 400 when Rack cannot parse a part for its encoding.
  #
  # A part can name a charset: `Content-Type: text/plain; charset=UTF-16LE`. Rack gives that charset
  # to the name of the part too. Its param parser then raises an encoding error for a charset that
  # is not ASCII-compatible (UTF-16, UTF-32, UTF-7). Without this middleware, the server answers
  # with a 500. No browser form sends such a part.
  #
  # The middleware parses the params of a multipart request before Rack::MethodOverride does. Rack
  # keeps the result in the env, so nothing parses the body twice. Each other error of the parser
  # passes: Rack and Rails handle it as before.
  #
  # Rack 2.2 raises a plain ArgumentError ("invalid byte sequence") for some of those parts. The
  # middleware answers that error with a 400 too.
  class MultipartEncodingGuard
    def initialize(app)
      @app = app
    end

    def call(env)
      return @app.call(env) unless unreadable_part?(env)

      # The request stops here, before Rack::TempfileReaper. So remove the temporary files that Rack
      # recorded for its uploads. Rack records none when its multipart parser raises the error. Ruby
      # then removes the files at garbage collection.
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

    # Whether the error is the plain ArgumentError of Rack 2.2 (see the class comment). The param
    # errors of Rack are subclasses of ArgumentError. Rack and Rails handle them, so they give
    # false.
    def invalid_part_name?(error)
      error.instance_of?(ArgumentError) && error.message.start_with?('invalid byte sequence')
    end
  end
end
