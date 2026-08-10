# frozen_string_literal: true

require 'rails_helper'

# Reproduces audit finding C1: the installer publishes a known default admin
# password on a permanently public page, and the installer itself is
# unauthenticated on a fresh deploy. See
# openspec/changes/harden-installer-default-admin.
RSpec.describe 'Installer and default-admin hardening', type: :request do
  describe 'GET /admin/installers/welcome on an already-installed site' do
    init_site # a site already exists

    it 'does not disclose the default admin credentials to a visitor who did not just install' do
      get welcome_cama_admin_installers_path

      expect(response.body).not_to include('admin123')
    end
  end

  describe 'POST /admin/installers/save on a fresh deploy' do
    # Site.count == 0 and no shared admin (users are global when users_share_sites is true).
    before { [CamaleonCms::Site, CamaleonCms::User].each(&:delete_all) }

    context 'when the request is remote' do
      before { allow_any_instance_of(ActionDispatch::Request).to receive(:local?).and_return(false) }

      it 'refuses to provision a site without a setup token' do
        expect do
          post save_cama_admin_installers_path, params: { site: { name: 'Attacker Site', slug: 'attacker' } }
        end.not_to change(CamaleonCms::Site, :count).from(0)
      end
    end

    context 'when the request is local (loopback)' do
      it 'provisions without a setup token, since local access already proves host access' do
        expect do
          post save_cama_admin_installers_path, params: { site: { name: 'Local Install', slug: 'local' } }
        end.to change(CamaleonCms::Site, :count).by(1)
      end
    end
  end

  describe 'the auto-provisioned administrator' do
    before { [CamaleonCms::Site, CamaleonCms::User].each(&:delete_all) }

    it 'is not created with the historical default password, and must change it' do
      CamaleonCms::Site.create!(name: 'Repro', slug: 'repro-site')
      admin = CamaleonCms::User.where(role: 'admin').last

      expect(admin).to be_present
      expect(admin.authenticate('admin123')).to be_falsey
      expect(admin.get_meta('must_change_password')).to be_present
    end
  end

  describe 'installing from a remote request with a valid setup token' do
    around do |example|
      ENV['CAMALEON_SETUP_TOKEN'] = 'valid-setup-token'
      [CamaleonCms::Site, CamaleonCms::User].each(&:delete_all)
      example.run
    ensure
      ENV.delete('CAMALEON_SETUP_TOKEN')
    end

    before { allow_any_instance_of(ActionDispatch::Request).to receive(:local?).and_return(false) }

    it 'provisions the site and shows the generated password once to the installing operator' do
      expect do
        post save_cama_admin_installers_path,
             params: { site: { name: 'Legit', slug: 'legit' }, setup_token: 'valid-setup-token' }
      end.to change(CamaleonCms::Site, :count).by(1)

      follow_redirect! # the welcome page, in the same session that just installed
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('cama_generated_password')

      # the one-time marker is consumed: a second visit no longer discloses anything
      get welcome_cama_admin_installers_path
      expect(response).to redirect_to(cama_admin_login_url)
    end
  end
end
