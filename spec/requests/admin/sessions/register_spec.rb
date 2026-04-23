# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'User registration mass assignment protection', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }

  before do
    current_site.set_option('permit_create_account', true)
    current_site.set_option('need_validate_email', true)
  end

  describe 'POST /admin/register' do
    context 'when attempting mass assignment of site_id' do
      it 'ignores injected site_id and creates user' do
        target_site_id = current_site.id + 999
        username = "massassign_#{Time.current.to_i}"

        post cama_admin_register_path, params: {
          user: {
            first_name: 'MassAssign',
            last_name: 'Test',
            email: "#{username}@tester.com",
            username: username,
            password: 'password123',
            password_confirmation: 'password123',
            site_id: target_site_id,
            is_valid_email: true,
            active: true
          }
        }

        user = CamaleonCms::User.find_by(username: username)
        expect(user).not_to be_nil
        # The user should exist on the current site (not the injected site_id)
        expect(user.site_id).not_to eq(target_site_id)
        # is_valid_email should be false (not the injected true)
        expect(user.is_valid_email).to be(false)
      end
    end

    context 'when attempting mass assignment of sensitive attributes' do
      it 'ignores injected role, auth_token, password_reset_token, confirm_email_token' do
        username = "sensitive_#{Time.current.to_i}"

        post cama_admin_register_path, params: {
          user: {
            first_name: 'Sensitive',
            last_name: 'Test',
            email: "#{username}@tester.com",
            username: username,
            password: 'password123',
            password_confirmation: 'password123',
            role: 'admin',
            auth_token: 'hacked_token',
            password_reset_token: 'reset_token',
            confirm_email_token: 'confirm_token'
          }
        }

        user = CamaleonCms::User.find_by(username: username)
        expect(user).not_to be_nil
        expect(user.role).to eq('client')
        expect(user.auth_token).not_to eq('hacked_token')
      end
    end
  end
end
