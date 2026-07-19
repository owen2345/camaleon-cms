# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CamaleonCms::Admin::MediaController, '#actions', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }

  context 'when user has media management permission' do
    let(:admin_role) { current_site.user_roles.create!(name: 'Media Admin', slug: 'media_admin') }
    let(:admin_user) { create(:user, role: admin_role.slug, site: current_site) }

    before do
      admin_role.set_meta("_manager_#{current_site.id}", { 'media' => 1 })
      allow_any_instance_of(described_class).to receive(:verify_media_authorization).and_return(true)
      sign_in_as(admin_user, site: current_site)
    end

    context 'when new_folder action' do
      it 'allows creating a new folder' do
        post '/admin/media/actions', params: { folder: '/test_folder', media_action: 'new_folder' }

        expect(response).to have_http_status(:ok)
      end
    end

    context 'when del_folder action' do
      it 'allows deleting a folder' do
        allow_any_instance_of(CamaleonCmsLocalUploader).to receive(:delete_folder).and_return(error: '')
        post '/admin/media/actions', params: { folder: '/test_folder', media_action: 'del_folder' }

        expect(response).to have_http_status(:ok)
      end
    end

    context 'when del_file action' do
      it 'allows deleting a file' do
        allow_any_instance_of(CamaleonCmsLocalUploader).to receive(:delete_file).and_return(error: '')
        post '/admin/media/actions', params: { folder: '/test_file.jpg', media_action: 'del_file' }

        expect(response).to have_http_status(:ok)
      end
    end

    context 'when crop_url action with a data: URI whose name contains path traversal' do
      # tmp_path is public/tmp/<site.id>, so "../cama_pwn_test.png" would escape one
      # level up to public/tmp/ before the fix stripped the name to its basename.
      let(:escape_target) { Rails.public_path.join('tmp', 'cama_pwn_test.png').to_s }

      before do
        # Isolate the base64 write (in cama_tmp_upload) from the downstream crop/upload
        # machinery, which is not under test here.
        allow_any_instance_of(described_class).to receive(:upload) { |controller, *| controller.render(plain: 'ok') }
      end

      after { FileUtils.rm_f(escape_target) }

      it 'does not write the base64 payload outside the site tmp dir' do
        payload = Base64.strict_encode64('fake-bytes')
        post '/admin/media/actions', params: {
          media_action: 'crop_url',
          url: "data:image/png;base64,#{payload}",
          name: '../cama_pwn_test.png',
          formats: 'png'
        }

        expect(File.exist?(escape_target)).to be(false)
      end
    end
  end

  context 'when user does NOT have media management permission' do
    let(:limited_role) { current_site.user_roles.create!(name: 'Limited User', slug: 'limited_user') }
    let(:limited_user) { create(:user, role: limited_role.slug, site: current_site) }

    before do
      limited_role.set_meta("_manager_#{current_site.id}", {})
      allow_any_instance_of(described_class).to receive(:verify_media_authorization).and_raise(CanCan::AccessDenied)
      sign_in_as(limited_user, site: current_site)
    end

    it 'blocks access and redirects' do
      post '/admin/media/actions', params: { folder: '/test_folder', media_action: 'new_folder' }

      expect(response).to redirect_to(/admin/)
      expect(flash[:error]).to be_present
    end
  end
end
