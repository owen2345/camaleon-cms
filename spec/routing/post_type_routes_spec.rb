require "rails_helper"

RSpec.describe "routes for Post Types", :type => :routing do
  it "routes for /test-post-type" do
    slug = "test-post-type-#{rand.to_s[2..10]}"
    post_type = create_test_post_type(slug: slug)
    expect(post_type.id).to be_present
    expect(get("/#{slug}")).to route_to(
      "camaleon_cms/frontend#post_type",
      post_type_id: post_type.id,
      post_type_slug: slug)
  end
end