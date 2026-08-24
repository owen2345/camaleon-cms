# frozen_string_literal: true

# frontend-cache-invalidation-scope — integration-level reproduction of the vulnerability fixed in
# PR #1279, through the real hook chain (front_cache is installed AND active by default on every
# site, see default_plugins in config/system.json).
#
# The login POST itself runs no front_cache hook: SessionsController inherits CamaleonController,
# which fires only session_before_load. What defeated the brute-force counter on master was any
# OTHER POST running the front_before_load/admin_before_load hooks — one cheap unauthenticated
# frontend POST (here: a comment) between login attempts ran front_cache_post_requests →
# front_cache_clean → Rails.cache.clear, wiping the attacker's own per-IP counter.
RSpec.describe 'Security: front_cache invalidation preserves the login brute-force counter',
               type: :request do
  let(:site) { CamaleonCms::Site.first }
  let(:admin) do
    create(:user_admin, site: site, username: 'fc-bf-admin',
                        password: 'admin-pass-1', password_confirmation: 'admin-pass-1')
  end
  let(:commented_post) do
    site.decorate.the_post('sample-post').tap { |p| p.set_meta('has_comments', '1') }
  end
  let(:counter_key) { "cama_captcha_attack:#{site.id}:127.0.0.1:login" }

  before do
    site.set_option('permit_anonimos_comment', true)
    Rails.cache.delete(counter_key)
  end

  def failed_login_attempt
    post cama_admin_login_path, params: { user: { username: admin.username, password: 'wrong' } }
  end

  it 'keeps the per-IP counter accumulated across an interleaved frontend POST' do
    2.times { failed_login_attempt }
    expect(Rails.cache.read(counter_key, raw: true).to_i).to eq(2)

    # The reset gadget on master: an unauthenticated frontend POST triggers front_cache_clean.
    post cama_save_comment_path(post_id: commented_post.id), params: {
      post_comment: { name: 'Anon', email: 'anon@tester.com', content: 'interleaved POST' }
    }

    expect(Rails.cache.read(counter_key, raw: true).to_i).to eq(2)
  end
end
