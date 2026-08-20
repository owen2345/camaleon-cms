# frozen_string_literal: true

require 'rails_helper'

include CamaleonCms::Frontend::ApplicationHelper

RSpec.describe 'PostDecorator' do
  init_site
  it 'next and previous post related to post type' do
    post_type = create(:post_type, slug: 'test-post-type', site: @site)
    post3 = create(:post, post_type: post_type, slug: 'test3', post_order: 3).decorate
    post1 = create(:post, post_type: post_type, slug: 'test1', post_order: 1).decorate
    post2 = create(:post, post_type: post_type, slug: 'test2', post_order: 2).decorate
    post2_1 = create(:post, post_type: post_type, slug: 'test2_1', post_order: 2).decorate
    post4 = create(:post, post_type: post_type, slug: 'test4', post_order: 4).decorate

    expect(post3.the_next_post.slug).to eq('test4')
    expect(post3.the_prev_post.slug).to eq('test2_1')

    expect(post2.the_prev_post.slug).to eq('test1')
    expect(post2.the_next_post.slug).to eq('test2_1')

    expect(post2_1.the_prev_post.slug).to eq('test2')
    expect(post2_1.the_next_post.slug).to eq('test3')

    expect(post1.the_prev_post).to be_nil
    expect(post1.the_next_post.slug).to eq('test2_1')

    expect(post4.the_prev_post.slug).to eq('test3')
    expect(post4.the_next_post).to be_nil
  end

  it 'featured post' do
    ptype = @site.post_types.last
    bk = ptype.posts.featured.count
    create(:featured_post, post_type: ptype)
    expect(ptype.posts.reload.featured.count).to eql(bk + 1)
  end

  it 'post with extra data' do
    ptype = @site.post_types.last
    ptype.set_option('has_comments', true)
    data = {
      thumb: 'https://camaleon.website/media/132/slider/slider-camaleon.jpg',
      summary: 'This is summary',
      has_comments: 0
    }
    post = create(:post, post_type: ptype, data_metas: data).decorate
    expect(post.get_meta('summary').present?).to be(true)
    expect(post.the_thumb_url).to include('slider-camaleon.jpg')
    expect(post.has_thumb?).to be(true)
    expect(post.manage_comments?).to be(true)
  end

  describe '#fix_post_order' do
    it 'assigns post_order 1 when creating the first post with nil post_order' do
      post_type = create(:post_type, site: @site)
      post = build(:post, post_type: post_type, post_order: nil)
      post.save
      expect(post.post_order).to eq(1)
    end

    it 'does not fail when the last post has a nil post_order' do
      post_type = create(:post_type, site: @site)
      first_post = create(:post, post_type: post_type, post_order: 1)
      first_post.update_column(:post_order, nil) # rubocop:disable Rails/SkipsModelValidations

      new_post = build(:post, post_type: post_type, post_order: nil)
      expect { new_post.save }.not_to raise_error
      expect(new_post.post_order).to eq(1)
    end

    it 'assigns post_order 2 when the last post has post_order 1' do
      post_type = create(:post_type, site: @site)
      create(:post, post_type: post_type, post_order: 1)

      new_post = build(:post, post_type: post_type, post_order: nil)
      new_post.save
      expect(new_post.post_order).to eq(2)
    end
  end
end
