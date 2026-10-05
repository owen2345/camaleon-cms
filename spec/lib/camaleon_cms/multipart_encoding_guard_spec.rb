# frozen_string_literal: true

# Calls the middleware directly, with a small Rack app after it.
RSpec.describe CamaleonCms::MultipartEncodingGuard do
  subject(:guard) { described_class.new(downstream) }

  let(:boundary) { 'AaB03x' }
  let(:reached) { [] }
  # The app after the middleware. It records each request that it gets, and it parses the params, as
  # Rack::MethodOverride and Rails do.
  let(:downstream) do
    lambda do |env|
      reached << env
      [200, {}, [Rack::Request.new(env).POST.to_a.flatten.join(',')]]
    end
  end

  # Each part is a name, a value, an optional charset and an optional file name.
  def multipart_body(parts)
    parts.map do |name, value, charset, filename|
      type = charset ? "Content-Type: text/plain; charset=#{charset}\r\n" : ''
      file = filename ? "; filename=\"#{filename}\"" : ''
      "--#{boundary}\r\nContent-Disposition: form-data; name=\"#{name}\"#{file}\r\n#{type}\r\n#{value}\r\n".b
    end.join << "--#{boundary}--\r\n".b
  end

  def env_for(body, type: "multipart/form-data; boundary=#{boundary}", method: 'POST')
    Rack::MockRequest.env_for('/admin/save', method: method, input: body, 'CONTENT_TYPE' => type,
                                             'CONTENT_LENGTH' => body.bytesize.to_s, 'rack.errors' => StringIO.new)
  end

  describe 'a part in a charset that is not ASCII-compatible' do
    let(:env) { env_for(multipart_body([%w[title plain], ['note[text]', 'x', 'UTF-16LE']])) }

    it 'answers with a 400 and lowercase header keys, and does not call the next app' do
      status, headers, body = guard.call(env)

      expect(status).to eq(400)
      expect(headers).to eq('content-type' => 'text/plain; charset=utf-8')
      expect(body).to eq(['Bad Request'])
      expect(reached).to be_empty
    end

    it 'writes one line to the error stream of the request' do
      guard.call(env)

      expect(env['rack.errors'].string.lines.size).to eq(1)
      expect(env['rack.errors'].string).to include('multipart part')
    end

    it 'gives each request its own response, so another middleware can change the headers' do
      first = guard.call(env)
      second = guard.call(env_for(multipart_body([%w[note x UTF-16LE]])))

      expect(first[1]).not_to be(second[1])
      expect(first[1]).not_to be_frozen
    end

    %w[PATCH PUT DELETE].each do |method|
      it "answers a #{method} with a 400" do
        status, = guard.call(env_for(multipart_body([%w[note x UTF-16LE]]), method: method))

        expect(status).to eq(400)
      end
    end
  end

  # The request stops before Rack::TempfileReaper, so the middleware removes the temporary files that
  # Rack recorded for the uploads.
  it 'removes the recorded temporary files of the uploads when it answers with a 400' do
    env = env_for(multipart_body([['upload', 'data', nil, 'a.txt'], ['note', 'x', 'UTF-16LE']]))

    status, = guard.call(env)

    expect(status).to eq(400)
    expect(env.fetch('rack.tempfiles').size).to eq(1)
    expect(env['rack.tempfiles']).to all(have_attributes(path: nil))
  end

  it 'gives a multipart request with readable parts to the next app, which reads the same params' do
    status, _headers, body = guard.call(env_for(multipart_body([%w[title plain], %w[note x ISO-8859-1]])))

    expect(status).to eq(200)
    expect(body).to eq(['title,plain,note,x'])
  end

  it 'gives a file part in such a charset to the next app, because Rack gives no charset to a file part' do
    status, = guard.call(env_for(multipart_body([['upload', 'data', 'UTF-16LE', 'a.txt']])))

    expect(status).to eq(200)
  end

  # Only a multipart part can name a charset, so the middleware reads no other body.
  it 'does not read the body of a request that is not multipart' do
    input = StringIO.new('note=x')
    env = env_for('note=x', type: 'application/x-www-form-urlencoded').merge('rack.input' => input)
    passed = described_class.new(->(given) { [200, {}, [given['rack.input'].pos.to_s]] })

    expect(passed.call(env).last).to eq(['0'])
  end

  # Rack 2.2 raises a plain ArgumentError for a part name with bytes that are invalid in the charset
  # of the part. CI runs Rack 3, so the examples stub the parser.
  describe 'an ArgumentError of the parser' do
    let(:env) { env_for(multipart_body([%w[note x]])) }

    def parser_raises(error)
      request = instance_double(Rack::Request, media_type: 'multipart/form-data')
      allow(request).to receive(:POST).and_raise(error)
      allow(Rack::Request).to receive(:new).with(env).and_return(request)
    end

    it 'answers with a 400 when the bytes of a part name are invalid in the charset' do
      parser_raises(ArgumentError.new('invalid byte sequence in UTF-16LE'))

      status, _headers, body = guard.call(env)

      expect(status).to eq(400)
      expect(body).to eq(['Bad Request'])
      expect(reached).to be_empty
    end

    it 'gives the request to the next app for another ArgumentError' do
      parser_raises(ArgumentError.new('wrong number of arguments'))

      expect { guard.call(env) }.to raise_error(ArgumentError, 'wrong number of arguments')
      expect(reached).to eq([env])
    end

    # Rack::QueryParser::InvalidParameterError is a subclass of ArgumentError. Rack and Rails handle it.
    it 'gives the request to the next app for a param error of Rack with the same message' do
      parser_raises(Rack::QueryParser::InvalidParameterError.new('invalid byte sequence in UTF-8'))

      expect { guard.call(env) }.to raise_error(Rack::QueryParser::InvalidParameterError)
      expect(reached).to eq([env])
    end
  end

  # The next app gets the same error when it parses the params.
  it 'gives a request with another error of the parser to the next app' do
    env = env_for(multipart_body([%w[note 1], %w[note[text] 2]]))

    expect { guard.call(env) }.to raise_error(Rack::QueryParser::ParameterTypeError)
    expect(reached).to eq([env])
    expect(env['rack.errors'].string).to be_empty
  end
end
