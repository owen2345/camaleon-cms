# frozen_string_literal: true

RSpec.describe CamaleonCms::Post do
  init_site

  let(:post_type) { create(:post_type, slug: 'published-at-pt', site: @site) }

  it 'leaves published_at nil for a post created as a draft' do
    post = create(:draft_post, post_type: post_type, published_at: nil)
    expect(post.published_at).to be_nil
  end

  it 'stamps published_at when a draft is published without a date' do
    post = create(:draft_post, post_type: post_type, published_at: nil)
    post.update!(status: 'published')
    expect(post.published_at).to be_within(5.seconds).of(Time.current)
  end

  it 'stamps published_at when a post is created already published without a date' do
    post = create(:post, post_type: post_type, status: 'published', published_at: nil)
    expect(post.published_at).to be_within(5.seconds).of(Time.current)
  end

  it 'preserves a caller-supplied published_at when publishing (scheduled post)' do
    scheduled = 3.days.from_now
    post = create(:draft_post, post_type: post_type, published_at: nil)
    post.update!(status: 'published', published_at: scheduled)
    expect(post.published_at).to be_within(1.second).of(scheduled)
  end

  it 'does not change published_at when an already-published post is edited' do
    original = 10.days.ago
    post = create(:post, post_type: post_type, status: 'published', published_at: original)
    post.update!(title: 'A new title')
    expect(post.reload.published_at).to be_within(1.second).of(original)
  end
end
