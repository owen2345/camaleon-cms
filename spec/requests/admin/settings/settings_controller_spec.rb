# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CamaleonCms::Admin::SettingsController, type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }

  before do
    allow_any_instance_of(CamaleonCms::AdminController).to receive(:cama_authenticate)
    allow_any_instance_of(CamaleonCms::AdminController).to receive(:current_site).and_return(current_site)
  end

  describe '#test_email' do
    let(:admin_role) { current_site.user_roles.create!(name: 'Admin', slug: 'admin') }
    let(:admin_user) { create(:user, role: admin_role.slug, site: current_site) }

    before do
      admin_role.set_meta("_manager_#{current_site.id}", { 'settings' => 1 })
    end

    context 'when email delivery succeeds' do
      it 'returns success response' do
        sign_in_as(admin_user, site: current_site)
        allow(CamaleonCms::HtmlMailer).to receive(:sender).and_return(double(deliver_now: true))

        get '/admin/settings/test_email', params: { email: 'test@example.com' }

        expect(response).to have_http_status(:ok)
      end
    end

    context 'when email delivery fails' do
      it 'renders error message as plain text, not as template' do
        sign_in_as(admin_user, site: current_site)
        error_message = '<%= system("ls") %>'
        allow(CamaleonCms::HtmlMailer).to receive(:sender).and_raise(StandardError.new(error_message))

        get '/admin/settings/test_email', params: { email: 'test@example.com' }

        expect(response).to have_http_status(502)
        expect(response.body).to eq(error_message)
        expect(response.content_type).to include('text/plain')
      end
    end
  end
end
