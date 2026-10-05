# frozen_string_literal: true

module CamaleonCms
  # Answers a multipart request with a 400 when Rack cannot read one of its parts for the encoding.
  #
  # The problem: a part of a multipart request can name a charset, for example
  # `Content-Type: text/plain; charset=UTF-16LE`. Rack gives that charset to the name of the part
  # too, and its param parser then compares the name with ASCII text. For a charset that is not
  # ASCII-compatible (UTF-16, UTF-32, UTF-7), that comparison raises an encoding error. Without this
  # middleware, the server answers such a request with a 500:
  # - For a POST, Rack::MethodOverride reads the params. It runs before the middleware of Rails that
  #   shows an error page for an exception, so the exception leaves the app.
  # - For another method, Rails reads the params later and gives its last-resort 500 page.
  # A browser form names no charset for a part, so only a hand-made request has such a part.
  #
  # What the middleware does: it reads the params of a multipart request with the parser of Rack,
  # before Rack::MethodOverride. Rack keeps the result in the env, so Rack and Rails do not parse the
  # body again. When the parser raises an encoding error, the middleware answers with a 400, and the
  # request stops here. The middleware does not catch another error of the parser: the request goes
  # on, and Rack and Rails handle that error as before.
  #
  # Rack 2.2 differs in one case. It raises the encoding error only when the bytes of the part name
  # are valid in the charset. For other bytes it raises a plain ArgumentError with the text "invalid
  # byte sequence". The middleware answers that error with a 400 too.
  class MultipartEncodingGuard
    def initialize(app)
      @app = app
    end

    def call(env)
      return @app.call(env) unless unreadable_part?(env)

      # Rack stores each uploaded file of the request in a temporary file. Rack::TempfileReaper
      # removes those files, but it runs later in the stack, and this request stops here. So the
      # middleware removes them.
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

    # Whether the error is the plain ArgumentError of Rack 2.2. Rack 2.2 raises it for a part name
    # with bytes that are not valid in the charset of the part. Rack also has param errors that are
    # subclasses of ArgumentError, such as Rack::QueryParser::InvalidParameterError. Rack and Rails
    # handle those, so the answer is false for them.
    def invalid_part_name?(error)
      error.instance_of?(ArgumentError) && error.message.start_with?('invalid byte sequence')
    end
  end
end
