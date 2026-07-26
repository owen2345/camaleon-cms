# frozen_string_literal: true

require 'rails_helper'

# updated_ajax is called by an admin modal form that renders the response body directly, and it
# already reports a missing password parameter as a status plus a short plain-text body. A target
# that cannot be resolved has to be reported the same way rather than falling through to the
# framework's default HTML error page.
#
# The 404 status itself is not new — ActiveRecord::RecordNotFound already maps to :not_found. Only
# the body format is. Note also that this endpoint needs no uniformity between found and not-found
# responses: validate_role admits only the target themselves or a holder of :manage on :users, so
# a caller who reaches this lookup with someone else's id can already enumerate users.
RSpec.describe 'updated_ajax unresolvable target', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  let(:admin_user) do
    create(:user, site: current_site, role: 'admin',
                  password: 'admin_secret', password_confirmation: 'admin_secret')
  end
  # Bystander proves no collateral write happens on the not-found path
  let(:bystander) do
    create(:user, site: current_site, role: 'client',
                  password: 'bystander_secret', password_confirmation: 'bystander_secret')
  end
  let(:not_found_message) { I18n.t('camaleon_cms.admin.users.message.error') }
  let(:password_params) { { password: { password: 'new_secret', password_confirmation: 'new_secret' } } }

  before do
    bystander
    post cama_admin_login_path, params: { user: { username: admin_user.username, password: 'admin_secret' } }
  end

  context 'when the id does not identify a user' do
    it 'answers with a plain-text 404 rather than an HTML error page' do
      patch '/admin/users/999999/updated_ajax', params: password_params

      expect(response).to have_http_status(:not_found)
      expect(response.body).to eq(not_found_message)
      expect(response.body).not_to include('<html')
    end

    it 'modifies no user record' do
      patch '/admin/users/999999/updated_ajax', params: password_params

      expect(bystander.reload.authenticate('bystander_secret')).to be_truthy
      expect(bystander.reload.authenticate('new_secret')).to be_falsey
      expect(admin_user.reload.authenticate('admin_secret')).to be_truthy
    end
  end

  context 'when the id is non-numeric' do
    it 'answers with the same plain-text 404' do
      patch '/admin/users/abc/updated_ajax', params: password_params

      expect(response).to have_http_status(:not_found)
      expect(response.body).to eq(not_found_message)
    end

    it 'modifies no user record' do
      patch '/admin/users/abc/updated_ajax', params: password_params

      expect(bystander.reload.authenticate('bystander_secret')).to be_truthy
      expect(admin_user.reload.authenticate('admin_secret')).to be_truthy
    end
  end

  context 'when the target resolves' do
    it 'keeps the existing parameter-error format unchanged' do
      patch "/admin/users/#{bystander.id}/updated_ajax", params: { password: { password: 'new_secret' } }

      expect(response).to have_http_status(:bad_request)
      expect(response.body).to start_with('ERROR: ActionController::ParameterMissing')
      expect(bystander.reload.authenticate('bystander_secret')).to be_truthy
    end
  end
end
