# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Security: XSS via params[:info] in flash messages', type: :request do
  let(:site) { CamaleonCms::Site.first }
  let(:admin_role) { site.user_roles.find_by!(slug: 'admin') }
  let(:admin_user) { create(:user, role: admin_role.slug, site: site) }
  let(:decorated_site) { site.decorate }

  before do
    admin_role.set_meta("_manager_#{site.id}", { 'posts' => 1, 'sites' => 1 })
    allow_any_instance_of(CamaleonCms::AdminController).to receive(:cama_authenticate)
    allow_any_instance_of(CamaleonCms::AdminController).to receive(:current_site).and_return(decorated_site)
    sign_in_as(admin_user, site: site)
  end

  it 'does not render unescaped XSS payload from params[:info] (vulnerability fixed)' do
    xss_payload = '<script>alert("XSS")</script>'

    get '/admin/dashboard', params: { info: xss_payload }

    expect(response.body).not_to include(xss_payload)
  end
end
