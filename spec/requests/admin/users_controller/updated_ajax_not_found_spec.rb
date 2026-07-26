# frozen_string_literal: true

require 'rails_helper'

# updated_ajax answers its other failure paths with a status and a short text body — 400 for a
# missing password parameter, 422 for a validation error. A target that cannot be resolved has to
# be reported the same way rather than falling through to the framework's HTML error page, so the
# endpoint presents one contract to any client.
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
    it 'keeps the existing parameter-error message unchanged' do
      patch "/admin/users/#{bystander.id}/updated_ajax", params: { password: { password: 'new_secret' } }

      expect(response).to have_http_status(:bad_request)
      expect(response.body).to start_with('ERROR: ActionController::ParameterMissing')
      expect(bystander.reload.authenticate('bystander_secret')).to be_truthy
    end
  end

  # All three failure paths answer as text/plain. They previously used `render inline:`, which
  # compiles its argument as an ERB template — needless for a fixed message, and a template
  # injection sink for the 422 path, whose body is built from validation messages.
  context 'when comparing the failure paths' do
    it 'answers every failure with a text/plain body' do
      patch '/admin/users/999999/updated_ajax', params: password_params
      expect(response.media_type).to eq('text/plain')

      patch "/admin/users/#{bystander.id}/updated_ajax", params: { password: { password: 'new_secret' } }
      expect(response.media_type).to eq('text/plain')

      patch "/admin/users/#{bystander.id}/updated_ajax",
            params: { password: { password: 'new_secret', password_confirmation: 'mismatch' } }
      # Asserted numerically rather than symbolically: :unprocessable_entity is deprecated in Rack
      # and :unprocessable_content only exists from Rack 3.1, but this suite runs against Rails 7.1
      # through 8.1. This matches the idiom already used in updated_ajax_spec.rb.
      expect(response.status).to eq(422)
      expect(response.media_type).to eq('text/plain')
    end
  end
end
