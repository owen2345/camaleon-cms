# frozen_string_literal: true

require 'rails_helper'

# Once the login key is under attack, solving a captcha used to reset the attack counter
# even when the password was wrong — one solve bought another window of captcha-free
# guesses. The counter must survive a captcha solve and clear only when the login itself
# succeeds.
RSpec.describe 'Security: captcha attack counter clears only on real success', type: :request do
  let(:site) { CamaleonCms::Site.first }
  let(:admin) do
    create(:user_admin, site: site, username: 'zq-counter-admin',
                        password: 'admin-pass-1', password_confirmation: 'admin-pass-1')
  end

  def login(password, captcha: nil)
    params = { user: { username: admin.username, password: password } }
    params[:captcha] = captcha if captcha
    post cama_admin_login_path, params: params
  end

  # Fetch a fresh captcha image and return the plaintext answer it stored in the session.
  def solved_captcha
    get cama_captcha_path
    Array(session[:cama_captcha]).first
  end

  def signed_in?
    cookies[:auth_token].present?
  end

  it 'keeps requiring a captcha until a login actually succeeds' do
    threshold = site.get_option('max_try_attack', 5).to_i
    (threshold + 1).times { login('wrong-password') }
    expect(session['cama_captcha_login']).to eq(threshold + 1)

    # A correct captcha with a wrong password must not clear the throttle...
    login('wrong-password', captcha: solved_captcha)
    expect(signed_in?).to be(false)
    expect(session['cama_captcha_login']).to eq(threshold + 2)

    # ...so the correct password without a captcha is still rejected...
    login('admin-pass-1')
    expect(signed_in?).to be(false)

    # ...and only captcha plus password together log in and clear the counter
    # (login_user rotates the session, so the key is reset and then discarded with it).
    login('admin-pass-1', captcha: solved_captcha)
    expect(signed_in?).to be(true)
    expect(session['cama_captcha_login'].to_i).to eq(0)
  end
end
