# frozen_string_literal: true

# save_comment records request.user_agent. It used to call force_encoding on it directly,
# which 500'd for clients that send no User-Agent header at all (curl, bots, API clients)
# and mutated the header string in place when one was present — raising FrozenError on a
# frozen string.
RSpec.describe 'Frontend: saving a comment', type: :request do
  let(:site) { CamaleonCms::Site.first }
  let(:commented_post) do
    site.decorate.the_post('sample-post').tap { |p| p.set_meta('has_comments', '1') }
  end

  before { site.set_option('permit_anonimos_comment', true) }

  it 'records a comment from a client that sends no User-Agent header' do
    expect do
      post cama_save_comment_path(post_id: commented_post.id), params: {
        post_comment: { name: 'Anon', email: 'anon@tester.com', content: 'No UA client' }
      }
    end.to change(CamaleonCms::PostComment, :count).by(1)
    expect(flash[:comment_submit][:error]).to be_blank
  end

  it 'does not mutate the User-Agent header string in place' do
    expect do
      # This file is frozen_string_literal, so the header value is frozen: any in-place
      # force_encoding of the request's string raises rather than passing silently.
      post cama_save_comment_path(post_id: commented_post.id), params: {
        post_comment: { name: 'Anon', email: 'anon@tester.com', content: 'Frozen UA client' }
      }, headers: { 'User-Agent' => 'FrozenAgent/1.0' }
    end.to change(CamaleonCms::PostComment, :count).by(1)
  end
end
