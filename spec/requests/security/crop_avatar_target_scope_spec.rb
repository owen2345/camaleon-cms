# frozen_string_literal: true

require 'rails_helper'

# Security (audit Low): media#crop resolved the avatar target with an unscoped
# `CamaleonCms::User.find(params[:saved_avatar])` — so a media manager on one site could set (or
# probe the existence of) a user on another site by passing that user's id. The target is now
# resolved through `current_site.users` and nil-safely, so a foreign id is a no-op, not a
# cross-tenant write or an existence oracle.
RSpec.describe 'Security: crop avatar target is site-scoped (Low)', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  let(:other_site) { CamaleonCms::Site.create!(name: 'Victim Site', slug: 'victim-site', taxonomy: 'site') }
  let(:admin_role) { current_site.user_roles.create!(name: 'Media Admin', slug: 'media_admin') }
  let(:admin_user) { create(:user, role: admin_role.slug, site: current_site) }
  let(:victim) { create(:user, site: other_site) }

  before do
    admin_role.set_meta("_manager_#{current_site.id}", { 'media' => 1 })
    # The cross-tenant exposure exists when users are NOT shared across sites; in shared mode every
    # user is legitimately reachable. current_site.users respects this config either way.
    allow(PluginRoutes).to receive(:system_info)
      .and_return(PluginRoutes.system_info.merge('users_share_sites' => false))
    # Two sites exist, so pin request resolution to the manager's own site (cross-site spec idiom).
    allow_any_instance_of(CamaleonCms::AdminController).to receive(:current_site).and_return(current_site)
    media = CamaleonCms::Admin::MediaController
    allow_any_instance_of(media).to receive(:verify_media_authorization).and_return(true)
    allow_any_instance_of(media).to receive(:cama_tmp_upload).and_return(file_path: '/tmp/test.jpg')
    allow_any_instance_of(media).to receive(:cama_crop_image).and_return('/tmp/cropped.jpg')
    allow_any_instance_of(media).to receive(:upload_file).and_return('url' => '/uploads/cropped.jpg')
    sign_in_as(admin_user, site: current_site)
  end

  # Meta reads memoize per instance; read through a fresh record so the controller's write is visible.
  def stored_avatar(user)
    CamaleonCms::User.find(user.id).get_meta('avatar')
  end

  it 'does not set an avatar on a user outside the current site' do
    victim.set_meta('avatar', '/uploads/original.jpg')

    post '/admin/media/crop', params: { cp_img_path: 'photo.jpg', saved_avatar: victim.id }

    expect(stored_avatar(victim)).to eq('/uploads/original.jpg')
  end

  it 'still sets the avatar for a user in the current site' do
    member = create(:user, site: current_site)

    post '/admin/media/crop', params: { cp_img_path: 'photo.jpg', saved_avatar: member.id }

    expect(stored_avatar(member)).to eq('/uploads/cropped.jpg')
  end
end
