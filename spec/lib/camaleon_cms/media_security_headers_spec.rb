# frozen_string_literal: true

require 'rails_helper'

# Unit-drives the middleware with a plain downstream app so the emitted header-key casing is
# asserted exactly (Rack 3 / Falcon require lowercase keys; Puma tolerates mixed case, which is
# why the request-level spec did not catch the mixed-case regression). Also pins the
# case-insensitive `/media/....svg` path match.
RSpec.describe CamaleonCms::MediaSecurityHeaders do
  subject(:middleware) { described_class.new(downstream) }

  let(:downstream) { ->(_env) { [200, {}, ['body']] } }

  def call(path, method: 'GET')
    middleware.call('REQUEST_METHOD' => method, 'PATH_INFO' => path)
  end

  it 'emits lowercase header keys for an SVG response' do
    _status, headers, _body = call('/media/1/x.svg')

    expect(headers.keys).to include('x-content-type-options', 'content-security-policy')
    expect(headers.keys).not_to include('X-Content-Type-Options', 'Content-Security-Policy')
    expect(headers['x-content-type-options']).to eq('nosniff')
    expect(headers['content-security-policy']).to eq("script-src 'none'")
  end

  it 'protects an uppercase .SVG path (case-insensitive match)' do
    _status, headers, _body = call('/media/1/x.SVG')

    expect(headers['content-security-policy']).to eq("script-src 'none'")
  end

  it 'leaves non-SVG responses untouched' do
    _status, headers, _body = call('/media/1/x.png')

    expect(headers).to be_empty
  end

  it 'ignores non-GET requests' do
    _status, headers, _body = call('/media/1/x.svg', method: 'POST')

    expect(headers).to be_empty
  end
end
