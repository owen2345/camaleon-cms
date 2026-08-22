# frozen_string_literal: true

require 'rails_helper'

# Regression (PR #1169 review finding #9, STALE-PROXY-SIBLINGS): every writer in
# CategoriesTagsForPosts mutates term_relationships directly, which does NOT invalidate an
# already-loaded categories/post_tags through-proxy; `pluck` on a loaded proxy then reads memory.
# update_categories/unassign_category reset the proxy, but assign_category, update_tags and the
# after_save check_default_category did not, so post.categories / post.the_tags kept serving the
# stale set (and tag counts corrupted) after a save. the_post now preloads categories (with_eager),
# so the proxy is routinely loaded before these writers run.
RSpec.describe CamaleonCms::Post, type: :model do
  let(:site) { create(:site) }
  let(:post_type) do
    pt = create(:post_type, site: site)
    pt.set_option('has_category', true)
    pt.set_option('has_tags', true)
    CamaleonCms::PostType.find(pt.id)
  end
  let(:cat_a) { post_type.categories.create!(name: 'Alpha', slug: "stale-a-#{rand(9999)}") }
  let(:cat_b) { post_type.categories.create!(name: 'Beta', slug: "stale-b-#{rand(9999)}") }
  let(:post) do
    post_type.posts.create!(title: 'Stale probe', slug: "stale-probe-#{rand(9999)}", status: 'published')
  end

  it 'assign_category reflects the new category through a loaded proxy' do
    post.assign_category([cat_b.id])
    post.categories.load # simulate the_post having eager-loaded categories

    post.assign_category([cat_a.id])

    expect(post.categories.map(&:id)).to include(cat_a.id)
    expect(post.categories.map(&:id)).to match_array(post.term_relationships.pluck(:term_taxonomy_id))
  end

  it 'update_tags drops removed tags from a loaded proxy' do
    post.update_tags('alpha,beta')
    post.post_tags.load # simulate a decorator/hook having read the tags

    post.update_tags('alpha')

    expect(post.post_tags.map(&:name)).to contain_exactly('alpha')
  end

  it 'exposes the auto-assigned default category right after create (not a stale empty set)' do
    fresh = post_type.posts.create!(title: 'Default probe', slug: "default-probe-#{rand(9999)}",
                                    status: 'published')

    expect(fresh.categories.map(&:id)).to include(post_type.default_category.id)
  end

  it 'keeps tag counts correct when the proxy was loaded before the tag was added' do
    # load the (empty) proxy BEFORE the tag exists -- the corruption only shows when the stale
    # target predates the tag, so update_counts never revisits it. (An add-then-remove that loads
    # the proxy after both tags exist passes even without the reset.)
    post.post_tags.load
    post.update_tags('alpha')
    post.update_tags('') # remove all tags

    alpha = post_type.post_tags.find_by(name: 'alpha')
    expect(alpha.reload.count).to eq(0)
  end

  it 'resets the term_relationships source proxy, not only the derived categories/tags proxies' do
    post.assign_category([cat_a.id])
    post.term_relationships.load # a loaded source proxy (through-preload or a prior read)

    post.update_categories([]) # destroys the relationship via the term_relationships scope

    # writers mutate term_relationships directly, so a loaded source proxy would stay stale unless
    # rescue_extra_data resets it too
    expect(post.term_relationships).to be_empty
    expect(post.categories).to be_empty
  end
end
