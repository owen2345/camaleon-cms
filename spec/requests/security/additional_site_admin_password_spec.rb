# frozen_string_literal: true

require 'rails_helper'

# When creating an additional site provisions a fresh administrator (users not shared across
# sites), the generated password must be surfaced exactly once to the authenticated creator —
# and never invented when no admin was minted. The shipped test config shares users across
# sites, so the minting branch is reachable only with users_share_sites stubbed off.
# See openspec/specs/default-admin-credential-safety/spec.md.
RSpec.describe 'Additional-site admin password surfacing', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  let(:admin) { create(:user, role: 'admin', site: current_site) }

  before do
    allow_any_instance_of(CamaleonCms::AdminController).to receive(:current_site).and_return(current_site)
    sign_in_as(admin, site: current_site)
  end

  context 'when users are not shared across sites (the new site mints its own admin)' do
    before do
      allow(PluginRoutes).to receive(:system_info)
        .and_return(PluginRoutes.system_info.merge('users_share_sites' => false))
    end

    it 'surfaces the generated password once to the creating administrator, with a copy control' do
      post cama_admin_settings_sites_path, params: { site: { name: 'Second Site', slug: 'second-site' } }

      expect(response).to have_http_status(:redirect)
      notice = flash[:notice]
      password = notice.to_s[/New administrator password: ([A-Za-z0-9]{16})/, 1]
      expect(password).to be_present
      expect(notice).to be_html_safe
      expect(notice).to include('navigator.clipboard')

      new_site = CamaleonCms::Site.find_by!(slug: 'second-site')
      minted = CamaleonCms::User.where(site_id: new_site.id, role: 'admin').first
      expect(minted).to be_present
      expect(minted.authenticate(password)).to be_truthy
      expect(minted.get_meta('must_change_password')).to be_present
    end
  end

  context 'when users are shared across sites (no admin is minted)' do
    it 'shows the plain confirmation without any password' do
      post cama_admin_settings_sites_path, params: { site: { name: 'Third Site', slug: 'third-site' } }

      expect(response).to have_http_status(:redirect)
      expect(flash[:notice]).to eq(I18n.t('camaleon_cms.admin.sites.message.created'))
      expect(flash[:notice].to_s).not_to match(/password/i)
    end
  end
end
