# frozen_string_literal: true

require 'rails_helper'

# H4 — an unauthenticated GET /captcha?len= must not build an unbounded image, and
# H3 — the session must hold only a single active challenge (the accumulation of every
# issued answer, combined with an attacker-shrinkable length, made the captcha bypassable).
RSpec.describe 'Security: captcha hardening (H3/H4)', type: :request do
  let(:site) { CamaleonCms::Site.first }

  # the plaintext answers currently stashed in the session for the captcha image(s)
  def captcha_answers
    Array(session[:cama_captcha])
  end

  it 'clamps an attacker-supplied length so the challenge cannot grow unbounded (H4)' do
    get cama_captcha_path, params: { len: '64' }

    expect(response).to have_http_status(:ok)
    expect(captcha_answers.last.length).to be <= 8
  end

  it 'does not shrink the challenge below a floor (H3 brute-force space)' do
    get cama_captcha_path, params: { len: '1' }

    expect(captcha_answers.last.length).to be >= 4
  end

  it 'keeps only one active challenge instead of accumulating every issued answer (H3)' do
    get cama_captcha_path
    get cama_captcha_path
    get cama_captcha_path

    expect(captcha_answers.size).to eq(1)
  end

  # Guard that the hardening does not lock legitimate users out: the current challenge still verifies.
  it 'still lets a legitimate registrant through with the correct current captcha' do
    site.set_option('permit_create_account', true)
    site.set_option('security_captcha_user_register', true)

    get cama_captcha_path
    answer = captcha_answers.first
    stamp = Time.now.to_i

    expect do
      post cama_admin_register_path, params: {
        user: { first_name: 'Reg', last_name: 'User', email: "reg_#{stamp}@tester.com",
                username: "reg_#{stamp}", password: 'passsword', password_confirmation: 'passsword' },
        captcha: answer
      }
    end.to change(CamaleonCms::User, :count).by(1)
  end
end
