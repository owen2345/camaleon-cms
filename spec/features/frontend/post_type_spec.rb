# frozen_string_literal: true

describe 'Posttype frontend', :js do
  before do
    @site = CamaleonCms::Site.first.decorate
    @post = @site.the_post('sample-post').decorate
    @post_type = @post.post_type.decorate
  end

  it 'public uri with group structure' do
    expect(@post_type.the_group_url(as_path: true)).to include("/group/#{@post_type.id}")
  end

  it 'public url' do
    expect(@post_type.the_url).to include("/#{@post_type.slug}")
  end
end
