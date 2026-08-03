# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Association target integrity', type: :model do
  let(:site) { CamaleonCms::Site.first }
  let(:post_type) { site.post_types.find_by(slug: 'post') }
  let(:user) { create(:user) }

  describe 'owner associations' do
    it 'returns the owning user for a category' do
      category = post_type.categories.create!(name: 'Owned category', slug: 'owned-category-x', user_id: user.id)

      expect { category.owner }.not_to raise_error
      expect(category.owner.id).to eq(user.id)
      expect(category.decorate.the_owner).to be_present
    end

    it 'never raises InverseOfAssociationNotFoundError on any owner reader' do
      [CamaleonCms::Category, CamaleonCms::PostType, CamaleonCms::PostTag, CamaleonCms::Widget::Main].each do |klass|
        expect { klass.new.owner }.not_to raise_error
      end
    end
  end

  describe 'site.nav_menu_items' do
    # The inverse is applied when the collection is fully loaded (enumeration), which is
    # where the wrong `inverse_of: :parent` overwrote each item's NavMenu with the Site.
    it 'keeps the NavMenu as the parent of items loaded through the site' do
      menu = site.nav_menus.create!(name: 'Integrity menu', slug: 'integrity-menu-x')
      item = menu.append_menu_item(label: 'Item', link: '/item', type: 'custom', target: '')
      item.update_column(:term_group, site.id) if item.term_group.blank? # rubocop:disable Rails/SkipsModelValidations

      loaded = site.nav_menu_items.to_a.find { |i| i.id == item.id }

      expect(loaded.parent).to eq(menu)
      expect(loaded.parent).to be_a(CamaleonCms::NavMenu)
    end
  end

  describe 'post.drafts' do
    it 'wires the parent inverse and keeps the author as owner' do
      parent = post_type.add_post(title: 'Draft parent', slug: 'draft-parent-x', content: 'body',
                                  user_id: user.id)
      post_type.posts.create!(title: 'Autosave', slug: 'draft-child-x', status: 'draft_child',
                              post_parent: parent.id, user_id: user.id, content: 'draft body')

      loaded_draft = CamaleonCms::Post.find(parent.id).drafts.to_a.first

      expect(loaded_draft.owner).not_to be_a(CamaleonCms::Post)
      expect(loaded_draft.owner.id).to eq(user.id)
      expect(loaded_draft.association(:parent)).to be_loaded
      expect(loaded_draft.parent.id).to eq(parent.id)
    end
  end
end
