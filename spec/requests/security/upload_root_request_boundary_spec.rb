# frozen_string_literal: true

# The allowed-root set may only be widened by application code. These pin that a request cannot
# reach it, so the crop sink (which passes params[:cp_img_path] into the path argument) keeps
# validating against the default roots.
#
# The assertions are on the argument the validator actually receives, not on the response body.
# Asserting only that the body omits `root:` passes on a 500, a redirect, or an empty response —
# on anything at all short of a verbatim /etc/passwd dump — so it could not fail for the reason
# the file exists.
RSpec.describe 'Upload root request boundary', type: :request do
  init_site

  let(:admin) { @site.users.admin_scope.first }
  let(:observed_roots) { [] }

  def auth_headers
    { 'HTTP_HOST' => @site.slug, 'HTTP_COOKIE' => "auth_token=#{admin.auth_token}&rspec&127.0.0.1" }
  end

  # Records every extra_roots the request ends up passing, while leaving the real validation in
  # place so the endpoint still behaves as it would in production.
  before do
    roots = observed_roots
    allow_any_instance_of(CamaleonCms::Admin::MediaController)
      .to receive(:cama_canonical_upload_path).and_wrap_original do |original, path, **kwargs|
        roots << kwargs.fetch(:extra_roots, [])
        original.call(path, **kwargs)
      end
  end

  shared_examples 'a request that cannot widen the roots' do
    it 'passes no extra roots to the path validator' do
      make_request

      expect(observed_roots).not_to be_empty, 'the path validator was never reached'
      expect(observed_roots.flatten).to be_empty
    end

    it 'does not resolve the traversal target' do
      make_request

      expect(response.body).not_to include('root:')
    end
  end

  context 'when cropping a source outside the default roots' do
    def make_request
      post '/admin/media/crop', params: { cp_img_path: '/etc/passwd', name: 'passwd.png' },
                                headers: auth_headers
    end

    include_examples 'a request that cannot widen the roots'

    it 'refuses the path' do
      make_request

      expect(response.body).to include('Invalid file path')
    end
  end

  context 'when the crop request supplies an allowed_roots parameter' do
    def make_request
      post '/admin/media/crop',
           params: { cp_img_path: '/etc/passwd', name: 'passwd.png', allowed_roots: ['/etc'] },
           headers: auth_headers
    end

    include_examples 'a request that cannot widen the roots'

    it 'refuses the path exactly as it does without the parameter' do
      make_request

      expect(response.body).to include('Invalid file path')
    end
  end

  context 'when the upload request supplies an allowed_roots parameter' do
    def make_request
      post '/admin/media/upload',
           params: { file_upload: '/etc/passwd', allowed_roots: ['/etc'], formats: '*' },
           headers: auth_headers
    end

    include_examples 'a request that cannot widen the roots'

    it 'refuses the path' do
      make_request

      expect(response.body).to include('Invalid file path')
    end
  end
end
