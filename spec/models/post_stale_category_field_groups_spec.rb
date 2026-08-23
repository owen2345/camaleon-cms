# frozen_string_literal: true

# Regression: unchecking a category in the post form destroys the term relationship in
# update_categories, but a LOADED categories association on the post still contained the removed id.
# get_field_groups unions categories.map(&:id) with the passed ids, so the removed category's field
# groups kept rendering in the edit form after the update. rescue_extra_data (called by every writer)
# now resets the association, so the read is fresh.
RSpec.describe CamaleonCms::Post, type: :model do
  describe '#get_field_groups after update_categories' do
    let!(:site) { create(:site) }
    let(:post_type) { site.post_types.first }
    let!(:category_a) { post_type.categories.create!(name: 'Alpha', slug: 'stale-alpha') }
    let!(:category_b) { post_type.categories.create!(name: 'Beta', slug: 'stale-beta') }
    let!(:group_a) do
      site.custom_field_groups.create!(name: 'Group A', slug: '_stale-group-a',
                                       object_class: 'Category_Post', objectid: category_a.id)
    end
    let!(:group_b) do
      site.custom_field_groups.create!(name: 'Group B', slug: '_stale-group-b',
                                       object_class: 'Category_Post', objectid: category_b.id)
    end
    let!(:post) do
      post = post_type.posts.create!(title: 'Stale categories test', slug: 'stale-categories-test',
                                     status: 'published')
      post.update_categories([category_a.id, category_b.id])
      post
    end

    it 'drops the removed category from get_field_groups despite a loaded association' do
      # the_post preloads categories (with_eager), so a loaded proxy is routine before
      # update_categories destroys a relationship
      post.categories.load
      post.update_categories([category_a.id])

      expect(post.categories.map(&:id)).to contain_exactly(category_a.id)

      groups = post.get_field_groups
      expect(groups).to include(group_a)
      expect(groups).not_to include(group_b)
    end
  end
end
