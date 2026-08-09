# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CamaleonCms::MediaSecurityHeaders, type: :request do
  init_site

  let(:svg_path) { '/media/1/test.svg' }
  let(:png_path) { '/media/1/test.png' }
  let(:upper_svg_path) { '/media/1/upper.SVG' }

  before do
    FileUtils.mkdir_p(Rails.public_path.join('media/1'))
    File.write(Rails.public_path.join('media/1/test.svg'), '<svg xmlns="http://www.w3.org/2000/svg"/>')
    File.write(Rails.public_path.join('media/1/test.png'), 'fake-png')
    File.write(Rails.public_path.join('media/1/upper.SVG'), '<svg xmlns="http://www.w3.org/2000/svg"/>')
  end

  after do
    FileUtils.rm_f(Rails.public_path.join('media/1/test.svg'))
    FileUtils.rm_f(Rails.public_path.join('media/1/test.png'))
    FileUtils.rm_f(Rails.public_path.join('media/1/upper.SVG'))
  end

  it 'adds X-Content-Type-Options nosniff to SVG responses under /media/' do
    get svg_path
    expect(response.headers['X-Content-Type-Options']).to eq('nosniff')
  end

  it 'adds Content-Security-Policy script-src none to SVG responses under /media/' do
    get svg_path
    expect(response.headers['Content-Security-Policy']).to eq("script-src 'none'")
  end

  it 'does not add security headers to non-SVG responses under /media/' do
    get png_path
    expect(response.headers['Content-Security-Policy']).to be_nil
  end

  it 'protects an uppercase .SVG served inline under /media/' do
    get upper_svg_path
    expect(response.headers['X-Content-Type-Options']).to eq('nosniff')
    expect(response.headers['Content-Security-Policy']).to eq("script-src 'none'")
  end
end
