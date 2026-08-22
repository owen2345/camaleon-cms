# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CamaleonCms::Post, type: :model do
  describe '#update_categories query efficiency' do
    let(:post_type) { CamaleonCms::Site.first.post_types.find_by(slug: 'post') }
    let(:cat_a) { post_type.categories.create!(name: 'Q A', slug: 'qcat-a') }
    let(:cat_b) { post_type.categories.create!(name: 'Q B', slug: 'qcat-b') }
    let(:post) { post_type.posts.create!(title: 'Q probe', slug: 'q-probe', status: 'published') }

    it 'reuses the rescue snapshot instead of re-plucking the existing categories before the write' do
      post.assign_category([cat_a.id])

      # categories and post_tags share the same through-pluck shape, so the two snapshot plucks
      # rescue_extra_data takes (@cats_before, @tags_before) both match; the point is that
      # old_categories reuses @cats_before rather than issuing a THIRD identical pluck before the write.
      through_pluck = /FROM "term_taxonomy" INNER JOIN "term_relationships"/i
      write = /(INSERT INTO|DELETE FROM) "term_relationships"/i
      sql = sql_queries { post.update_categories([cat_a.id, cat_b.id]) }

      first_write = sql.index { |s| s.match?(write) } || sql.size
      plucks_before_write = sql[0...first_write].count { |s| s.match?(through_pluck) }

      expect(plucks_before_write).to eq(2)
      expect(post.categories.reload.pluck(:id)).to contain_exactly(cat_a.id, cat_b.id)
    end

    it 'does not create duplicate term_relationships for repeated category ids' do
      post.update_categories([cat_a.id, cat_a.id])

      expect(post.term_relationships.where(term_taxonomy_id: cat_a.id).count).to eq(1)
      expect(post.categories.reload.pluck(:id)).to contain_exactly(cat_a.id)
    end
  end
end
