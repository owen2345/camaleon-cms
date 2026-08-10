# frozen_string_literal: true

require 'rails_helper'

# A newly provisioned administrator is minted with a random password and a must-change marker
# (see harden-installer-default-admin). The admin panel must funnel such an account to the
# change-password screen until it sets its own password.
RSpec.describe 'Forced password change for a newly provisioned admin', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  let(:admin) { current_site.users.where(role: 'admin').first }

  def marker_for(user)
    CamaleonCms::User.find(user.id).get_meta('must_change_password')
  end

  context 'when the admin still owes a password change' do
    before do
      admin.set_meta('must_change_password', true)
      sign_in_as(admin, site: current_site)
    end

    it 'redirects other admin-panel requests to the change-password screen' do
      get cama_admin_dashboard_path
      expect(response).to redirect_to(cama_admin_profile_edit_path)
    end

    it 'lets the change-password screen through' do
      get cama_admin_profile_edit_path
      expect(response).to have_http_status(:ok)
    end

    it 'clears the marker and restores access once the password is changed' do
      patch cama_admin_user_updated_ajax_path(user_id: admin.id),
            params: { password: { password: 'NewStrongPass9', password_confirmation: 'NewStrongPass9' } }

      expect(marker_for(admin)).to be_blank

      get cama_admin_dashboard_path
      expect(response).to have_http_status(:ok)
    end
  end

  context 'when a pre-existing admin carries no marker' do
    before { sign_in_as(admin, site: current_site) }

    it 'reaches the admin panel without being forced to change anything' do
      get cama_admin_dashboard_path
      expect(response).to have_http_status(:ok)
    end
  end
end
