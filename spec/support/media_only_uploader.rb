# frozen_string_literal: true

# Gives an example a user who has the `media` permission and does not have
# `media_unfiltered_upload`, and sends a file to the media endpoint as that user. The request specs
# of the upload scan use it.
RSpec.shared_context 'with a media-only uploader' do
  let(:current_site) { Cama::Site.first.decorate }
  let(:media_only_role) { current_site.user_roles.create!(name: 'Media only', slug: 'media-only-upload-scan') }
  let(:media_only_user) { create(:user, role: media_only_role.slug, site: current_site) }
  let(:refusal) { 'Potentially malicious content found!' }

  before { media_only_role.set_meta("_manager_#{current_site.id}", { 'media' => 1 }) }

  def upload(content, extension: '.svg')
    sign_in_as(media_only_user, site: current_site)
    file = Tempfile.new(['upload-scan', extension], binmode: true)
    file.write(content)
    file.rewind
    post '/admin/media/upload',
         params: { file_upload: Rack::Test::UploadedFile.new(file.path, 'application/octet-stream'), folder: '' }
  ensure
    file&.close!
  end
end
