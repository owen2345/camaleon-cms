# frozen_string_literal: true

RSpec.describe CamaleonCms::Admin::SettingsController, type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }

  before do
    allow_any_instance_of(CamaleonCms::AdminController).to receive(:cama_authenticate)
    allow_any_instance_of(CamaleonCms::AdminController).to receive(:current_site).and_return(current_site)
  end

  describe '#test_email' do
    let(:admin_role) { current_site.user_roles.find_by!(slug: 'admin') }
    let(:admin_user) { create(:user, role: admin_role.slug, site: current_site) }

    before do
      admin_role.set_meta("_manager_#{current_site.id}", { 'settings' => 1 })
    end

    context 'when email delivery succeeds' do
      it 'returns success response' do
        sign_in_as(admin_user, site: current_site)
        allow(CamaleonCms::HtmlMailer).to receive(:sender).and_return(double(deliver_now: true))

        post '/admin/settings/test_email', params: { email: 'test@example.com' }

        expect(response).to have_http_status(:ok)
      end
    end

    context 'when email delivery fails' do
      it 'renders error message as plain text, not as template' do
        sign_in_as(admin_user, site: current_site)
        error_message = '<%= system("ls") %>'
        allow(CamaleonCms::HtmlMailer).to receive(:sender).and_raise(StandardError.new(error_message))

        post '/admin/settings/test_email', params: { email: 'test@example.com' }

        expect(response).to have_http_status(:bad_gateway)
        expect(response.body).to eq(error_message)
        expect(response.content_type).to include('text/plain')
      end
    end

    # Security (audit M6): test_email is POST-only, so the dialog that calls it must submit over POST
    # (jquery_ujs' prefilter then attaches the CSRF token). A revert of the dialog to $.get would
    # silently 404 against the converted route; a full :js spec of the modal is disproportionate for
    # this one-line caller, so pin the rendered caller directly.
    it 'wires the test-email dialog to $.post, not a CSRF-exempt GET' do
      sign_in_as(admin_user, site: current_site)

      get '/admin/settings/site'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("$.post(link.attr('href')")
      expect(response.body).not_to include("$.get(link.attr('href')")
    end
  end
end
