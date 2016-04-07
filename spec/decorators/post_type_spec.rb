require "rails_helper"

RSpec.describe "PostTypeDecorator", :type => :routing do
  it "group url" do
    post_type = create_test_post_type(slug: 'test-post-type')
    expect(post_type.decorate.the_group_url).to include("/group/#{post_type.id}")
  end

  it "public url" do
    post_type = create_test_post_type(slug: 'test-post-type')
    expect(post_type.decorate.the_url).to include("/#{post_type.slug}")
  end
end