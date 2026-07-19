# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CamaleonCms::Admin::MediaController, '#crop', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }

  context 'when user has media management permission' do
    let(:admin_role) { current_site.user_roles.create!(name: 'Media Admin', slug: 'media_admin') }
    let(:admin_user) { create(:user, role: admin_role.slug, site: current_site) }

    before { admin_role.set_meta("_manager_#{current_site.id}", { 'media' => 1 }) }

    it 'allows access to crop endpoint (authorization check passes)' do
      allow_any_instance_of(described_class).to receive(:verify_media_authorization).and_return(true)
      allow_any_instance_of(described_class).to receive(:cama_tmp_upload).and_return(file_path: '/tmp/test.jpg')
      allow_any_instance_of(described_class).to receive(:cama_crop_image).and_return('/tmp/cropped.jpg')
      allow_any_instance_of(described_class).to receive(:upload_file).and_return('url' => '/uploads/cropped.jpg')
      sign_in_as(admin_user, site: current_site)
      get '/admin/media/crop'

      expect(response.status).not_to eq(403)
    end

    it 'returns the cropped url as plain text' do
      allow_any_instance_of(described_class).to receive(:verify_media_authorization).and_return(true)
      allow_any_instance_of(described_class).to receive(:cama_tmp_upload).and_return(file_path: '/tmp/test.jpg')
      allow_any_instance_of(described_class).to receive(:cama_crop_image).and_return('/tmp/cropped.jpg')
      allow_any_instance_of(described_class).to receive(:upload_file).and_return(
        'url' => '/uploads/<script>alert(1)</script>.jpg'
      )
      sign_in_as(admin_user, site: current_site)

      get '/admin/media/crop'

      expect(response.media_type).to eq('text/plain')
      expect(response.body).to eq('/uploads/<script>alert(1)</script>.jpg')
    end
  end

  context 'when cp_img_path is a server file path (path traversal attempt)' do
    let(:admin_role) { current_site.user_roles.create!(name: 'Media Admin', slug: 'media_admin') }
    let(:admin_user) { create(:user, role: admin_role.slug, site: current_site) }

    before do
      admin_role.set_meta("_manager_#{current_site.id}", { 'media' => 1 })
      allow_any_instance_of(described_class).to receive(:verify_media_authorization).and_return(true)
      sign_in_as(admin_user, site: current_site)
    end

    it 'rejects crop with cp_img_path set to a server absolute path' do
      get '/admin/media/crop', params: { cp_img_path: '/etc/passwd' }

      expect(response.body).to include('Invalid file path')
    end

    it 'rejects crop with path traversal after allowed prefix' do
      allowed = Rails.public_path.to_s
      get '/admin/media/crop', params: { cp_img_path: "#{allowed}/../../../etc/passwd" }

      expect(response.body).to include('Invalid file path')
    end
  end

  context 'when cp_img_path is an HTTP URL (URL validation)' do
    let(:admin_role) { current_site.user_roles.create!(name: 'Media Admin', slug: 'media_admin') }
    let(:admin_user) { create(:user, role: admin_role.slug, site: current_site) }
    let(:site_url) { current_site.decorate.the_url(locale: nil) }

    before do
      admin_role.set_meta("_manager_#{current_site.id}", { 'media' => 1 })
      allow_any_instance_of(described_class).to receive(:verify_media_authorization).and_return(true)
      allow_any_instance_of(described_class).to receive(:cama_crop_image).and_return('/tmp/cropped.jpg')
      allow_any_instance_of(described_class).to receive(:upload_file).and_return('url' => '/uploads/cropped.jpg')
      sign_in_as(admin_user, site: current_site)
    end

    it 'passes through a valid same-origin HTTP URL' do
      allow(CamaleonCms::UserUrlValidator).to receive(:validate)
        .with("#{site_url}/media/1/photo.jpg", reject_path_traversal: true).and_return(true)
      # rubocop:disable RSpec/StubbedMock
      expect_any_instance_of(described_class).to receive(:cama_tmp_upload)
        .with("#{site_url}/media/1/photo.jpg").and_return(file_path: '/tmp/test.jpg')
      # rubocop:enable RSpec/StubbedMock

      get '/admin/media/crop', params: { cp_img_path: "#{site_url}/media/1/photo.jpg" }

      expect(response.status).not_to eq(400)
    end

    it 'rejects an HTTP URL containing path traversal segments' do
      traversal_url = "#{site_url}/../config/secrets.yml"
      allow(CamaleonCms::UserUrlValidator).to receive(:validate)
        .with(traversal_url, reject_path_traversal: true).and_return(['Path traversal detected'])
      expect_any_instance_of(described_class).not_to receive(:cama_tmp_upload)
      get '/admin/media/crop', params: { cp_img_path: traversal_url }

      expect(response.body).to include('Path traversal detected')
    end

    it 'passes through a non-URL path without controller-level validation' do
      expect(CamaleonCms::UserUrlValidator).not_to receive(:validate)
      # rubocop:disable RSpec/StubbedMock
      expect_any_instance_of(described_class).to receive(:cama_tmp_upload)
        .with('/etc/passwd').and_return(error: 'Invalid file path')
      # rubocop:enable RSpec/StubbedMock

      get '/admin/media/crop', params: { cp_img_path: '/etc/passwd' }
    end

    it 'passes through a data: URI without controller-level validation' do
      data_uri = 'data:image/png;base64,iVBORw0KGgo='
      expect(CamaleonCms::UserUrlValidator).not_to receive(:validate)
      # rubocop:disable RSpec/StubbedMock
      expect_any_instance_of(described_class).to receive(:cama_tmp_upload)
        .with(data_uri).and_return(file_path: '/tmp/test.png')
      # rubocop:enable RSpec/StubbedMock

      get '/admin/media/crop', params: { cp_img_path: data_uri }
    end
  end

  context 'when user does NOT have media management permission' do
    let(:limited_role) { current_site.user_roles.create!(name: 'Limited User', slug: 'limited_user') }
    let(:limited_user) { create(:user, role: limited_role.slug, site: current_site) }

    before { limited_role.set_meta("_manager_#{current_site.id}", {}) }

    it 'blocks access and redirects' do
      allow_any_instance_of(described_class).to receive(:verify_media_authorization).and_raise(CanCan::AccessDenied)
      sign_in_as(limited_user, site: current_site)
      get '/admin/media/crop'

      expect(response).to redirect_to(/admin/)
      expect(flash[:error]).to be_present
    end
  end
end
