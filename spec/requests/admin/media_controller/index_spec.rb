# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CamaleonCms::Admin::MediaController, '#index', type: :request do
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

    it 'allows access to index' do
      get '/admin/media'

      expect(response).to have_http_status(:ok)
    end

    # End-to-end guard for the M27 page seam (#1242): the legacy-thumb repair mutates the record
    # in place on the paginated relation, and the view iterates the same loaded page. If that
    # mutation stopped reaching the view (e.g. the seam returned a fresh array), the rendered
    # <img src> would fall back to the 404ing .jpg. The unit specs only exercise the .to_a path.
    it 'renders the repaired legacy thumbnail url on the page' do
      uploader = CamaleonCmsLocalUploader.new(current_site: current_site)
      media_root = uploader.instance_variable_get(:@root_folder)
      thumb_dir = File.join(media_root, 'thumb')
      FileUtils.mkdir_p(thumb_dir)
      File.write(File.join(thumb_dir, 'photo-jpg.png'), 'x') # only the legacy .png exists on disk
      uploader.send(:get_media_collection).create!(
        name: 'photo.jpg', folder_path: '/', is_folder: false, is_public: false,
        file_type: 'image', url: '/media/1/photo.jpg', thumb: '/media/1/thumb/photo-jpg.jpg'
      )

      get '/admin/media'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('/media/1/thumb/photo-jpg.png')
      expect(response.body).not_to include('/media/1/thumb/photo-jpg.jpg')
    ensure
      # Disk state outlives the DB transaction: remove the whole per-site media root the setup
      # created (the uploader constructor mkdir_p's it), not just the thumb subdirectory. The
      # nil check keeps a setup failure from being masked by an error here.
      FileUtils.rm_rf(media_root) if media_root
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
      get '/admin/media'

      expect(response).to redirect_to(/admin/)
      expect(flash[:error]).to be_present
    end
  end
end
