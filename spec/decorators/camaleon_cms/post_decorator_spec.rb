require 'rails_helper'

RSpec.describe CamaleonCms::PostDecorator do
  it "next and previous post related to post type" do
    post_type = create_test_post_type(slug: 'test-post-type')
    post3 = create_test_post(post_type, slug: 'test3', post_order: 3).decorate
    post1 = create_test_post(post_type, slug: 'test1', post_order: 1).decorate
    post2 = create_test_post(post_type, slug: 'test2', post_order: 2).decorate
    post2_1 = create_test_post(post_type, slug: 'test2_1', post_order: 2).decorate
    post4 = create_test_post(post_type, slug: 'test4', post_order: 4).decorate
    
    expect(post3.the_next_post.slug).to eq('test4')
    expect(post3.the_prev_post.slug).to eq('test2_1')

    expect(post2.the_prev_post.slug).to eq('test1')
    expect(post2.the_next_post.slug).to eq('test2_1')

    expect(post2_1.the_prev_post.slug).to eq('test2')
    expect(post2_1.the_next_post.slug).to eq('test3')

    expect(post1.the_prev_post).to eq(nil)
    expect(post1.the_next_post.slug).to eq('test2_1')

    expect(post4.the_prev_post.slug).to eq('test3')
    expect(post4.the_next_post).to eq(nil)
  end
end
