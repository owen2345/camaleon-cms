# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Model API compatibility', type: :model do
  init_site

  let(:site) { Cama::Site.first }

  describe 'Media.find_by_key' do
    let!(:folder) { site.public_media.create!(name: 'compat', folder_path: '/', is_folder: true) }

    it 'returns the same records as by_key' do
      # rubocop:disable Rails/DynamicFindBy
      legacy = site.public_media.find_by_key('/compat')
      # rubocop:enable Rails/DynamicFindBy

      expect(legacy).to eq(site.public_media.by_key('/compat'))
      expect(legacy).to contain_exactly(folder)
    end
  end

  describe '#unassign_category' do
    # has_category makes manage_categories? true, so the restored method's counter
    # refresh actually runs (it also auto-assigns the post type's default category
    # on save, which the assertions tolerate)
    let(:post_type) do
      create(:post_type, slug: 'compat-pt', site: @site).tap { |pt| pt.set_option(:has_category, true) }
    end
    let(:cat_a) { post_type.categories.create!(name: 'Cat A', slug: 'compat-cat-a') }
    let(:cat_b) { post_type.categories.create!(name: 'Cat B', slug: 'compat-cat-b') }
    let(:post) { create(:post, post_type: post_type, slug: 'compat-post', status: 'published') }

    before { post.assign_category([cat_a.id, cat_b.id]) }

    it 'removes the assignment and refreshes the category counters' do
      expect(cat_a.reload.count).to eq(1)

      post.unassign_category(cat_a.id)

      remaining = post.categories.reload.pluck(:id)
      expect(remaining).to include(cat_b.id)
      expect(remaining).not_to include(cat_a.id)
      expect(cat_a.reload.count).to eq(0)
      expect(cat_b.reload.count).to eq(1)
    end

    it 'accepts an array of ids' do
      post.unassign_category([cat_a.id, cat_b.id])

      remaining = post.categories.reload.pluck(:id)
      expect(remaining).not_to include(cat_a.id)
      expect(remaining).not_to include(cat_b.id)
      expect(cat_b.reload.count).to eq(0)
    end
  end
end
