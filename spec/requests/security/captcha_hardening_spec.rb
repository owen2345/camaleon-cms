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

  it 'rejects a registration whose captcha does not match the current challenge' do
    site.set_option('permit_create_account', true)
    site.set_option('security_captcha_user_register', true)

    get cama_captcha_path # a challenge exists, but the submission does not match it
    stamp = Time.now.to_i

    expect do
      post cama_admin_register_path, params: {
        user: { first_name: 'Reg', last_name: 'User', email: "wrong_#{stamp}@tester.com",
                username: "wrong_#{stamp}", password: 'passsword', password_confirmation: 'passsword' },
        captcha: 'WRONG1'
      }
    end.not_to change(CamaleonCms::User, :count)
  end

  it 'rejects a registration that submits no captcha at all' do
    site.set_option('permit_create_account', true)
    site.set_option('security_captcha_user_register', true)

    get cama_captcha_path
    stamp = Time.now.to_i

    expect do
      post cama_admin_register_path, params: {
        user: { first_name: 'Reg', last_name: 'User', email: "blank_#{stamp}@tester.com",
                username: "blank_#{stamp}", password: 'passsword', password_confirmation: 'passsword' }
      }
    end.not_to change(CamaleonCms::User, :count)
  end

  # Same guard for the anonymous-comment flow, which replaces the browser happy path in
  # spec/features/frontend/pages_spec.rb (a single-use challenge cannot be read and then
  # resubmitted across page loads there).
  describe 'anonymous comments' do
    let(:commented_post) do
      site.decorate.the_post('sample-post').tap { |p| p.set_meta('has_comments', '1') }
    end

    before do
      site.set_option('permit_anonimos_comment', true)
      site.set_option('enable_captcha_for_comments', true)
    end

    it 'still lets an anonymous commenter through with the correct current captcha' do
      get cama_captcha_path
      answer = captcha_answers.first

      expect do
        # save_comment records request.user_agent, which real browsers always send; it also
        # force-encodes the header string in place, so hand it an unfrozen copy.
        post cama_save_comment_path(post_id: commented_post.id), params: {
          post_comment: { name: 'Anon', email: 'anon@tester.com', content: 'A fine post' },
          captcha: answer
        }, headers: { 'User-Agent' => +'RSpec' }
      end.to change(CamaleonCms::PostComment, :count).by(1)
      expect(flash[:comment_submit][:error]).to be_blank
    end

    it 'rejects an anonymous comment whose captcha does not match the current challenge' do
      get cama_captcha_path

      expect do
        post cama_save_comment_path(post_id: commented_post.id), params: {
          post_comment: { name: 'Anon', email: 'anon@tester.com', content: 'A fine post' },
          captcha: 'WRONG1'
        }
      end.not_to change(CamaleonCms::PostComment, :count)
      expect(flash[:comment_submit][:error]).to be_present
    end
  end
end
