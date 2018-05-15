require 'rails_helper'
describe "Posttype frontend", js: true do
  before(:each) do
    @site = create(:site).decorate
    @post = @site.the_post('sample-post').decorate
    @post_type = @post.post_type.decorate
  end

  it 'public uri with group structure' do
    expect(@post_type.the_group_url(as_path: true)).to include("/group/#{@post_type.id}")
  end

  it "public url" do
    expect(@post_type.the_url).to include("/#{@post_type.slug}")
  end
end