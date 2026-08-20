# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'New folder request', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }

  context 'when user has media management permission' do
    let(:admin_role) { current_site.user_roles.create!(name: 'Media Admin', slug: 'media_admin') }
    let(:admin_user) { create(:user, role: admin_role.slug, site: current_site) }

    before do
      admin_role.set_meta("_manager_#{current_site.id}", { 'media' => 1 })
      allow_any_instance_of(CamaleonCms::Admin::MediaController)
        .to receive(:verify_media_authorization).and_return(true)
      sign_in_as(admin_user, site: current_site)
    end

    it 'creates the new folder' do
      post '/admin/media/actions', params: { folder: '/test2', media_action: 'new_folder' }

      expect(Dir).to exist(File.join(current_site.upload_directory, '/test2'))
    end
  end

  context 'when user does NOT have media management permission' do
    let(:limited_role) { current_site.user_roles.create!(name: 'Limited User', slug: 'limited_user') }
    let(:limited_user) { create(:user, role: limited_role.slug, site: current_site) }

    before do
      limited_role.set_meta("_manager_#{current_site.id}", {})
      allow_any_instance_of(CamaleonCms::Admin::MediaController).to receive(:verify_media_authorization).and_raise(CanCan::AccessDenied)
      sign_in_as(limited_user, site: current_site)
    end

    it 'blocks access and redirects' do
      post '/admin/media/actions', params: { folder: '/test2', media_action: 'new_folder' }

      expect(response).to redirect_to(/admin/)
      expect(flash[:error]).to be_present
    end
  end

  context 'when the folder path is invalid' do
    let(:admin_role) { current_site.user_roles.create!(name: 'Media Admin', slug: 'media_admin') }
    let(:admin_user) { create(:user, role: admin_role.slug, site: current_site) }

    before do
      admin_role.set_meta("_manager_#{current_site.id}", { 'media' => 1 })
      allow_any_instance_of(CamaleonCms::Admin::MediaController)
        .to receive(:verify_media_authorization).and_return(true)
      sign_in_as(admin_user, site: current_site)
    end

    it 'returns invalid file path error' do
      post '/admin/media/actions', params: { folder: '/../test3', media_action: 'new_folder' }

      expect(Dir).not_to exist(File.join(current_site.upload_directory, '/../test3'))
      expect(response.body).to include('Invalid folder path')
    end
  end
end
