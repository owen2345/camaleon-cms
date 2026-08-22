# frozen_string_literal: true

require 'rails_helper'

# The with_eager scope carries the eager-loading contract for every frontend post listing
# (verify_front_visibility applies it). It MUST stay preload-shaped, never includes/eager_load:
# an `includes` relation flips to `eager_loading?` the moment a caller chains a join/reference on
# one of the eager-loaded tables (PostDecorator#the_related_posts joins :categories), collapsing
# into one multi-way LEFT JOIN that loads a PARTIAL categories set per post and duplicates rows in
# pluck/count. `preload` runs separate queries and never merges into a join. (PR #1169 review,
# JOIN-PROMOTION / WITH-EAGER-DEAD.)
RSpec.describe CamaleonCms::Post, type: :model do
  describe '.with_eager' do
    it 'is preload-shaped (never includes/eager_load)' do
      relation = described_class.with_eager

      expect(relation.preload_values).to include(:metas, :categories, post_type: :metas)
      expect(relation.includes_values).to be_empty
      expect(relation.eager_load_values).to be_empty
    end

    it 'does not promote to a JOIN when a joined/referenced filter is chained' do
      relation = described_class.with_eager
                                .joins(:categories)
                                .where(CamaleonCms::TermRelationship.table_name => { term_taxonomy_id: [0] })

      expect(relation.eager_loading?).to be(false)
      expect(relation.to_sql).not_to include('LEFT OUTER JOIN')
    end
  end

  describe 'no partial association load or row duplication through the scope' do
    let(:site) { create(:site) }
    let(:post_type) do
      pt = create(:post_type, site: site)
      pt.set_option('has_category', true) # memoized `options` is stale on this instance
      CamaleonCms::PostType.find(pt.id)
    end
    let(:cat_a) { post_type.categories.create!(name: 'Alpha', slug: "eager-alpha-#{rand(9999)}") }
    let(:cat_b) { post_type.categories.create!(name: 'Beta', slug: "eager-beta-#{rand(9999)}") }
    let!(:post) do
      p = post_type.posts.create!(title: 'Eager probe', slug: "eager-probe-#{rand(9999)}", status: 'published')
      p.assign_category([cat_a.id, cat_b.id])
      p.set_meta('m1', '1')
      p.set_meta('m2', '2')
      p
    end

    it 'loads the full categories set when the scope is chained with a filtered category join' do
      # the_related_posts shape: filter by ONE category, but the loaded association must stay whole.
      relation = post_type.posts.with_eager
                          .joins(:categories)
                          .where(CamaleonCms::TermRelationship.table_name => { term_taxonomy_id: [cat_a.id] })
      loaded = relation.to_a.find { |r| r.id == post.id }

      expect(loaded.association(:categories).loaded?).to be(true)
      # cat_b is NOT in the filter, so its presence proves the association loaded whole (with
      # `includes` the filtered join would have loaded only cat_a).
      expect(loaded.categories.map(&:id)).to include(cat_a.id, cat_b.id)
    end

    it 'does not duplicate rows in pluck for a post with several metas and categories' do
      expect(post_type.posts.with_eager.where(id: post.id).pluck(:id)).to eq([post.id])
      expect(post_type.posts.with_eager.where(id: post.id).count).to eq(1)
    end
  end
end
