# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Download private file requests', type: :request do
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

    context 'when the file path is valid and file exists' do
      before do
        allow_any_instance_of(CamaleonCmsLocalUploader).to receive(:fetch_file).and_return('some_file')

        allow_any_instance_of(CamaleonCms::Admin::MediaController).to receive(:send_file)
        allow_any_instance_of(CamaleonCms::Admin::MediaController).to receive(:default_render)
      end

      it 'allows the file to be downloaded' do
        expect_any_instance_of(CamaleonCms::Admin::MediaController)
          .to receive(:send_file).with('some_file', disposition: 'inline')

        get '/admin/media/download_private_file', params: { file: 'some_file' }

        expect(response).not_to have_http_status(403)
        expect(response).to have_http_status(200)
      end
    end

    context 'when file path is invalid' do
      it 'returns invalid file path error' do
        get '/admin/media/download_private_file', params: { file: './../../../../../etc/passwd' }

        expect(response.body).to include('Invalid file path')
      end
    end

    context 'when the file is not found' do
      it 'returns file not found error' do
        allow_any_instance_of(CamaleonCmsLocalUploader)
          .to receive(:fetch_file).and_return(error: 'File not found')
        get '/admin/media/download_private_file', params: { file: 'passwd' }

        expect(response.body).to include('File not found')
      end
    end
  end

  context 'when user does NOT have media management permission' do
    let(:limited_role) { current_site.user_roles.create!(name: 'Limited User', slug: 'limited_user') }
    let(:limited_user) { create(:user, role: limited_role.slug, site: current_site) }

    before do
      limited_role.set_meta("_manager_#{current_site.id}", {})
      allow_any_instance_of(CamaleonCms::Admin::MediaController)
        .to receive(:verify_media_authorization).and_raise(CanCan::AccessDenied)
      sign_in_as(limited_user, site: current_site)
    end

    it 'blocks access and redirects' do
      get '/admin/media/download_private_file', params: { file: 'some_file' }

      expect(response).to redirect_to(/admin/)
      expect(flash[:error]).to be_present
    end
  end
end
