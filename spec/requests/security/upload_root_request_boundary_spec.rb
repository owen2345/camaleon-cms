# frozen_string_literal: true

require 'rails_helper'

# The allowed-root set may only be widened by application code. These pin that a request
# cannot reach it, so the crop sink (which passes params[:cp_img_path] into the path
# argument) keeps validating against the default roots.
RSpec.describe 'Upload root request boundary', type: :request do
  init_site

  let(:admin) { @site.users.admin_scope.first }

  def auth_headers
    { 'HTTP_HOST' => @site.slug, 'HTTP_COOKIE' => "auth_token=#{admin.auth_token}&rspec&127.0.0.1" }
  end

  it 'rejects a crop source outside the default roots' do
    post '/admin/media/crop', params: { cp_img_path: '/etc/passwd', name: 'passwd.png' },
                              headers: auth_headers

    expect(response.body).not_to include('root:')
    expect(response.body.downcase).to match(/invalid|error|not permitted/i).or be_blank
  end

  it 'does not let an allowed_roots parameter widen the crop source' do
    post '/admin/media/crop',
         params: { cp_img_path: '/etc/passwd', name: 'passwd.png', allowed_roots: ['/etc'] },
         headers: auth_headers

    expect(response.body).not_to include('root:')
  end

  it 'does not let an allowed_roots parameter widen the upload source' do
    post '/admin/media/upload',
         params: { file_upload: '/etc/passwd', allowed_roots: ['/etc'], formats: '*' },
         headers: auth_headers

    expect(response.body).not_to include('root:')
  end
end
