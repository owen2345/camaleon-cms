# frozen_string_literal: true

# H1 — admin login has no real brute-force protection. The "under attack" decision is a per-session
# counter (session["cama_captcha_login"]), so an attacker who drops their session cookie each request
# always looks fresh, never triggers the captcha, and can guess passwords without limit. The throttle
# must be server-side and keyed on the client (IP), and must hard-block an IP after enough failures.
RSpec.describe 'Security: admin login brute-force throttle (H1)', type: :request do
  let(:site) { CamaleonCms::Site.first }
  let(:admin) do
    create(:user_admin, site: site, username: 'bf-admin',
                        password: 'admin-pass-1', password_confirmation: 'admin-pass-1')
  end
  let(:soft) { site.get_option('max_try_attack', 5).to_i }

  def attempt(password)
    post cama_admin_login_path, params: { user: { username: admin.username, password: password } }
  end

  def signed_in?
    cookies[:auth_token].present?
  end

  # Drop the session cookie the way a cookieless / cookie-rotating attacker does.
  def drop_session
    cookies.delete('_dummy_session')
  end

  it 'stays gated after the client drops its session cookie (cookieless bypass closed)' do
    (soft + 1).times { attempt('wrong-password') }

    # With the per-session counter over the threshold, the correct password without a captcha is
    # rejected (a captcha is required) — this already holds on master.
    attempt('admin-pass-1')
    expect(signed_in?).to be(false)

    # The attacker drops the session to reset the per-session counter, then submits the correct
    # password with no captcha. On master this logs straight in; the fix keeps it gated by the per-IP
    # signal, which a fresh session does not reset.
    drop_session
    attempt('admin-pass-1')
    expect(signed_in?).to be(false)
  end

  it 'hard-locks the IP after too many failures, regardless of credentials' do
    site.set_option('login_lockout_attempts', 8) # keep the test small
    9.times { attempt('wrong-password') }

    # Even the correct password is now refused from this IP for the cooldown window.
    attempt('admin-pass-1')
    expect(response).to have_http_status(:too_many_requests)
    expect(signed_in?).to be(false)
  end

  it 'answers a locked-out JSON client with a JSON 429 body, not an HTML page' do
    site.set_option('login_lockout_attempts', 3)
    3.times { attempt('wrong-password') }

    post cama_admin_login_path(format: :json),
         params: { user: { username: admin.username, password: 'admin-pass-1' } }

    expect(response).to have_http_status(:too_many_requests)
    expect(response.media_type).to eq('application/json')
    expect(JSON.parse(response.body)).to include('error')
    expect(signed_in?).to be(false)
  end
end
