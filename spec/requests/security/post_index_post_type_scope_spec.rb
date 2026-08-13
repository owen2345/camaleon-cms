# frozen_string_literal: true

require 'rails_helper'

# Security (audit 2026-08-11 M11): the admin post index authorizes `:posts` on the post type named in
# the URL, but a taxonomy filter (`?taxonomy=category|post_tag&taxonomy_id=...`) replaced the
# post-type-scoped relation with the taxonomy owner's own posts -- site-scoped but not
# post-type-scoped. A user authorized on post type A could pass a category/tag id belonging to post
# type B and list B's posts (with `?s=all`, in every status), crossing a post-type authorization
# boundary. The listing must stay intersected with the authorized post type's posts.
RSpec.describe 'Security: admin post index post-type scoping', type: :request do
  init_site

  let(:current_site) { Cama::Site.first.decorate }
  let(:owner) { create(:user, role: 'admin', site: current_site) }
  let(:post_type_a) { create(:post_type, slug: 'pt-a', site: current_site) }
  let(:post_type_b) { create(:post_type, slug: 'pt-b', site: current_site) }

  # A user who may list/edit post type A's posts (edit_other => no own-posts filter) but has no
  # permission at all on post type B.
  let(:role_a) { current_site.user_roles.create!(name: 'Editor A', slug: 'editor-a') }
  let(:attacker) { create(:user, role: role_a.slug, site: current_site) }

  before do
    allow_any_instance_of(CamaleonCms::AdminController).to receive(:current_site).and_return(current_site)
    role_a.set_meta("_post_type_#{current_site.id}", { 'edit_other' => [post_type_a.id.to_s] })
    sign_in_as(attacker, site: current_site)
  end

  def category_for(post_type, name)
    CamaleonCms::Category.create!(name: name, slug: name.parameterize, site_id: current_site.id,
                                  parent_id: post_type.id, taxonomy: :category, status: post_type.id)
  end

  def tag_for(post_type, name)
    post_type.post_tags.create!(name: name, slug: name.parameterize)
  end

  it "does not leak another post type's posts through a category filter" do
    category_b = category_for(post_type_b, 'Secret Cat B')
    post_b = post_type_b.posts.create!(title: 'CONFIDENTIAL B POST', slug: 'confidential-b',
                                       user_id: owner.id, status: 'pending')
    post_b.categories << category_b

    get "/admin/post_type/#{post_type_a.id}/posts",
        params: { taxonomy: 'category', taxonomy_id: category_b.id, s: 'all' }

    expect(response.body).not_to include('CONFIDENTIAL B POST')
  end

  it "still lists the post type's own posts filtered by its own category" do
    category_a = category_for(post_type_a, 'Cat A')
    post_a = post_type_a.posts.create!(title: 'VISIBLE A POST', slug: 'visible-a',
                                       user_id: owner.id, status: 'published')
    post_a.categories << category_a

    get "/admin/post_type/#{post_type_a.id}/posts",
        params: { taxonomy: 'category', taxonomy_id: category_a.id }

    expect(response.body).to include('VISIBLE A POST')
  end

  it "does not leak another post type's posts through a tag filter" do
    tag_b = tag_for(post_type_b, 'Secret Tag B')
    post_b = post_type_b.posts.create!(title: 'CONFIDENTIAL B TAGGED POST', slug: 'confidential-b-tagged',
                                       user_id: owner.id, status: 'pending')
    post_b.post_tags << tag_b

    get "/admin/post_type/#{post_type_a.id}/posts",
        params: { taxonomy: 'post_tag', taxonomy_id: tag_b.id, s: 'all' }

    expect(response.body).not_to include('CONFIDENTIAL B TAGGED POST')
  end

  it "still lists the post type's own posts filtered by its own tag" do
    tag_a = tag_for(post_type_a, 'Tag A')
    post_a = post_type_a.posts.create!(title: 'VISIBLE A TAGGED POST', slug: 'visible-a-tagged',
                                       user_id: owner.id, status: 'published')
    post_a.post_tags << tag_a

    get "/admin/post_type/#{post_type_a.id}/posts",
        params: { taxonomy: 'post_tag', taxonomy_id: tag_a.id }

    expect(response.body).to include('VISIBLE A TAGGED POST')
  end
end
