# frozen_string_literal: true

require 'rails_helper'

# Security (object-level authorization + tenancy): media#crop writes a user's avatar from
# `saved_avatar`. Two boundaries govern that target:
#   * Object level: writing ANOTHER user's avatar is a user-management write, so it requires
#     `:manage, :users` -- the same capability `UsersController#update` already enforces. A caller
#     may always set their OWN avatar with just the media permission the endpoint requires.
#   * Tenancy (PR #1267): the target is resolved through `current_site.users`, so a user of another
#     site is unreachable when users are not shared -- for an authorized caller a foreign id is a
#     silent no-op, not an error or a cross-tenant write.
# The decision is derived from the `saved_avatar` parameter, before the target is resolved and before
# any upload/crop work, so a denied caller cannot tell whether a same-site user exists.
RSpec.describe 'Security: crop avatar target authorization', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  let(:other_site) { CamaleonCms::Site.create!(name: 'Victim Site', slug: 'victim-site', taxonomy: 'site') }
  let(:victim) { create(:user, site: other_site) }

  before do
    # The cross-tenant exposure exists when users are NOT shared across sites; in shared mode every
    # user is legitimately reachable. current_site.users respects this config either way.
    allow(PluginRoutes).to receive(:system_info)
      .and_return(PluginRoutes.system_info.merge('users_share_sites' => false))
    # Two sites exist, so pin request resolution to the acting user's own site (cross-site spec idiom).
    allow_any_instance_of(CamaleonCms::AdminController).to receive(:current_site).and_return(current_site)
    media = CamaleonCms::Admin::MediaController
    # Bypass only the media gate; the object-level :manage, :users check runs for real.
    allow_any_instance_of(media).to receive(:verify_media_authorization).and_return(true)
    allow_any_instance_of(media).to receive(:cama_tmp_upload).and_return(file_path: '/tmp/test.jpg')
    allow_any_instance_of(media).to receive(:cama_crop_image).and_return('/tmp/cropped.jpg')
    allow_any_instance_of(media).to receive(:upload_file).and_return('url' => '/uploads/cropped.jpg')
  end

  # Meta reads memoize per instance; read through a fresh record so the controller's write is visible.
  def stored_avatar(user)
    CamaleonCms::User.find(user.id).get_meta('avatar')
  end

  context 'when the caller is a media-only manager (holds :manage, :media, not :manage, :users)' do
    let(:media_role) { current_site.user_roles.create!(name: 'Media Only', slug: 'media_only') }
    let(:media_user) { create(:user, role: media_role.slug, site: current_site) }

    before do
      media_role.set_meta("_manager_#{current_site.id}", { 'media' => 1 })
      sign_in_as(media_user, site: current_site)
    end

    it 'sets their own avatar (self-service needs no user-management permission)' do
      post '/admin/media/crop', params: { cp_img_path: 'photo.jpg', saved_avatar: media_user.id }

      expect(response).to have_http_status(:ok)
      expect(stored_avatar(media_user)).to eq('/uploads/cropped.jpg')
    end

    # Reproduction: on the vulnerable code this WROTE the other user's avatar.
    it "is denied another same-site user's avatar" do
      member = create(:user, site: current_site)
      member.set_meta('avatar', '/uploads/original.jpg')

      post '/admin/media/crop', params: { cp_img_path: 'photo.jpg', saved_avatar: member.id }

      expect(response).to have_http_status(:redirect)
      expect(stored_avatar(member)).to eq('/uploads/original.jpg')
    end

    it "is denied a foreign-site user's avatar" do
      victim.set_meta('avatar', '/uploads/original.jpg')

      post '/admin/media/crop', params: { cp_img_path: 'photo.jpg', saved_avatar: victim.id }

      expect(response).to have_http_status(:redirect)
      expect(stored_avatar(victim)).to eq('/uploads/original.jpg')
    end

    # No existence oracle: a same-site id, a foreign id, a nonexistent id and a non-numeric value are
    # all denied with the same redirect, disclosing nothing about which users exist.
    it 'denies non-self targets identically regardless of whether the id exists' do
      member = create(:user, site: current_site)
      statuses = [member.id, victim.id, 999_999, 'abc'].map do |id|
        post '/admin/media/crop', params: { cp_img_path: 'photo.jpg', saved_avatar: id }
        response.status
      end

      expect(statuses).to all(eq(302))
    end
  end

  context 'when the caller is a user manager (holds :manage, :users)' do
    let(:manager_role) { current_site.user_roles.create!(name: 'User Manager', slug: 'user_manager') }
    let(:manager_user) { create(:user, role: manager_role.slug, site: current_site) }

    before do
      manager_role.set_meta("_manager_#{current_site.id}", { 'media' => 1, 'users' => 1 })
      sign_in_as(manager_user, site: current_site)
    end

    it "sets another same-site user's avatar" do
      member = create(:user, site: current_site)

      post '/admin/media/crop', params: { cp_img_path: 'photo.jpg', saved_avatar: member.id }

      expect(response).to have_http_status(:ok)
      expect(stored_avatar(member)).to eq('/uploads/cropped.jpg')
    end

    # Tenancy no-op: a foreign-site target is silently unreachable (not an error) for an authorized
    # caller, because current_site.users does not include it.
    it "leaves a foreign-site user's avatar unchanged with no error" do
      victim.set_meta('avatar', '/uploads/original.jpg')

      post '/admin/media/crop', params: { cp_img_path: 'photo.jpg', saved_avatar: victim.id }

      expect(response).to have_http_status(:ok)
      expect(stored_avatar(victim)).to eq('/uploads/original.jpg')
    end
  end
end
