# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'updated_ajax request', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  let(:current_user) { create(:user_admin, site: current_site, password: 'secret', password_confirmation: 'secret') }

  before do
    allow_any_instance_of(CamaleonCms::AdminController).to receive(:cama_authenticate)
    allow_any_instance_of(CamaleonCms::Admin::UsersController).to receive(:validate_role).and_return(true)
  end

  context 'when receiving correct params' do
    it "updates user's password" do
      expect(current_user.authenticate('secret')).to be_truthy
      expect(current_user.authenticate('new password')).to be_falsey

      patch "/admin/users/#{current_user.id}/updated_ajax",
            params: { password: { password: 'new password', password_confirmation: 'new password' } }

      expect(response.status).to eql(204)
      expect(response.body).to eql('')
      expect(current_user.reload.authenticate('secret')).to be_falsey
      expect(current_user.reload.authenticate('new password')).to be_truthy
    end
  end

  context 'when receiving incorrect params' do
    context 'when wrong password confirmation' do
      it "doesn't update user's password and return error" do
        expect(current_user.authenticate('secret')).to be_truthy

        patch "/admin/users/#{current_user.id}/updated_ajax",
              params: { password: { password: 'new password', password_confirmation: 'old password' } }

        expect(response.status).to eql(422)
        expect(response.body).to eql("Password confirmation doesn't match Password")
        expect(current_user.reload.authenticate('secret')).to be_truthy
      end
    end

    context 'when missing password confirmation' do
      it "doesn't update user's password" do
        expect(current_user.authenticate('secret')).to be_truthy

        patch "/admin/users/#{current_user.id}/updated_ajax", params: { password: { password: 'new password' } }

        expect(response.status).to eql(400)
        expect(response.body).to start_with(
          'ERROR: ActionController::ParameterMissing, param is missing or the value is empty'
        )
        expect(response.body).to include('password_confirmation')
        expect(current_user.reload.authenticate('secret')).to be_truthy
        expect(current_user.reload.authenticate('new password')).to be_falsey
      end
    end

    context 'when passing unpermitted params' do
      it 'ignores the unpermitted param' do
        expect(current_user.authenticate('secret')).to be_truthy

        # Changing this to false, because the receiver is not only yielded to the blocks, but also passed as an
        # unexpected additional argument to the `originall.call`
        RSpec::Mocks.configuration.yield_receiver_to_any_instance_implementation_blocks = false

        allow_any_instance_of(CamaleonCms::User).to receive(:update).and_call_original

        expect_any_instance_of(CamaleonCms::User)
          .to receive(:update).with(password: 'new password', password_confirmation: 'new password')

        patch "/admin/users/#{current_user.id}/updated_ajax",
              params: { password: { password: 'new password', password_confirmation: 'new password', role: 'admin' } }

        expect(response.status).to eql(204)
        expect(response.body).to eql('')
        expect(current_user.reload.authenticate('secret')).to be_falsey
        expect(current_user.reload.authenticate('new password')).to be_truthy

        # returning the default configuration
        RSpec::Mocks.configuration.yield_receiver_to_any_instance_implementation_blocks = false
      end
    end
  end
end
