# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CamaleonCms::Admin::MediaController, '#ajax', type: :request do
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

    it 'allows access to ajax endpoint' do
      get '/admin/media/ajax'

      expect(response).to have_http_status(200)
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

    it 'blocks access to ajax endpoint' do
      get '/admin/media/ajax'

      expect(response).to redirect_to(/admin/)
      expect(flash[:error]).to be_present
    end
  end
end
