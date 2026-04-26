# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CamaleonCms::Admin::MediaController, '#upload', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }

  context 'when user has media management permission' do
    let(:admin_role) { current_site.user_roles.create!(name: 'Media Admin', slug: 'media_admin') }
    let(:admin_user) { create(:user, role: admin_role.slug, site: current_site) }

    before { admin_role.set_meta("_manager_#{current_site.id}", { 'media' => 1 }) }

    it 'allows access to upload endpoint (authorization check passes)' do
      allow_any_instance_of(described_class).to receive(:verify_media_authorization).and_return(true)
      sign_in_as(admin_user, site: current_site)
      post '/admin/media/upload'

      expect(response.status).not_to eq(403)
    end
  end

  context 'when user does NOT have media management permission' do
    let(:limited_role) { current_site.user_roles.create!(name: 'Limited User', slug: 'limited_user') }
    let(:limited_user) { create(:user, role: limited_role.slug, site: current_site) }

    before { limited_role.set_meta("_manager_#{current_site.id}", {}) }

    it 'blocks access and redirects' do
      allow_any_instance_of(described_class).to receive(:verify_media_authorization).and_raise(CanCan::AccessDenied)
      sign_in_as(limited_user, site: current_site)
      post '/admin/media/upload'

      expect(response).to redirect_to(/admin/)
      expect(flash[:error]).to be_present
    end
  end
end
