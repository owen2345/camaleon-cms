# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CamaleonCms::SessionHelper, type: :helper do
  include described_class

  before do
    CurrentRequest.reset
  end

  describe '#login_user_with_password' do
    it 'authenticates found user' do
      user = instance_double(CamaleonCms::User)
      users = instance_double(ActiveRecord::Relation)
      site = instance_double(CamaleonCms::Site, users: users)

      allow(helper).to receive_messages(current_site: site, params: {})
      allow(users).to receive(:find_by).with(username: 'admin').and_return(user)
      allow(helper).to receive(:hooks_run)
      allow(user).to receive(:authenticate).with('secret').and_return(true)

      expect(helper.login_user_with_password('admin', 'secret')).to be(true)
    end
  end

  describe '#cama_register_user' do
    it 'registers user and returns it in the response payload for callers' do
      user = instance_double(CamaleonCms::User)
      users = instance_double(ActiveRecord::Relation)
      site = instance_double(
        CamaleonCms::Site,
        users: users,
        security_user_register_captcha_enabled?: false,
        need_validate_email?: false
      )

      allow(helper).to receive_messages(
        current_site: site,
        params: {},
        t: 'created',
        cama_admin_login_path: '/admin/login'
      )
      allow(users).to receive(:new).and_return(user)
      allow(helper).to receive(:hook_run)
      allow(helper).to receive(:hooks_run)
      allow(user).to receive(:save).and_return(true)
      allow(user).to receive(:set_metas)

      result = helper.cama_register_user({ username: 'john' }, {})

      expect(result).to include(result: true, message: 'created', redirect_url: '/admin/login')
      expect(result[:user]).to eq(user)
    end
  end

  describe '#cama_current_user' do
    it 'returns request-cached user from CurrentRequest' do
      cached = instance_double(CamaleonCms::User)
      CurrentRequest.user = cached

      expect(helper.cama_current_user).to eq(cached)
    end

    it 'resolves from auth token and stores in CurrentRequest' do
      users = instance_double(ActiveRecord::Relation)
      site = instance_double(CamaleonCms::Site, users_include_admins: users)
      found_user = instance_double(CamaleonCms::User)
      decorated_user = instance_double(CamaleonCms::User)

      allow(helper).to receive_messages(
        current_site: site,
        cama_calc_api_current_user: nil,
        cookie_auth_token_complete?: true,
        user_auth_token_from_cookie: 'token'
      )
      allow(users).to receive(:find_by).with(auth_token: 'token').and_return(found_user)
      allow(found_user).to receive(:decorate).and_return(decorated_user)

      expect(helper.cama_current_user).to eq(decorated_user)
      expect(CurrentRequest.user).to eq(decorated_user)
    end
  end
end
