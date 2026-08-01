# frozen_string_literal: true

require 'rails_helper'

# A custom field group carries tenancy in `parent_id` (which site owns it) and placement in
# `object_class` + `objectid` (which record's admin page displays it). `Site#get_field_groups` must
# read placement -- reading tenancy is what produced https://github.com/owen2345/camaleon-cms/issues/1124.
RSpec.describe CamaleonCms::Site, type: :model do
  describe '#get_field_groups' do
    let!(:site) { create(:site) }
    let(:post_type) { site.post_types.first }
    let(:theme) { site.get_theme }
    let(:nav_menu) { site.nav_menus.first || site.nav_menus.create!(name: 'Main', slug: 'main-menu') }

    let!(:site_group) do
      site.custom_field_groups.create!(
        name: 'Site Group', slug: '_site-group', object_class: 'Site', objectid: site.id
      )
    end

    it "returns the site's own groups" do
      expect(site.get_field_groups).to include(site_group)
    end

    it 'excludes groups placed on a post type' do
      group = site.custom_field_groups.create!(
        name: 'PT Group', slug: '_pt-group', object_class: 'PostType_Post', objectid: post_type.id
      )

      expect(site.get_field_groups).not_to include(group)
    end

    it 'excludes groups placed on a theme' do
      group = site.custom_field_groups.create!(
        name: 'Theme Group', slug: '_theme-group', object_class: 'Theme', objectid: theme.id
      )

      expect(site.get_field_groups).not_to include(group)
    end

    it 'excludes groups placed on a nav menu' do
      group = site.custom_field_groups.create!(
        name: 'Menu Group', slug: '_menu-group', object_class: 'NavMenu', objectid: nav_menu.id
      )

      expect(site.get_field_groups).not_to include(group)
    end

    it 'excludes groups placed on users' do
      group = site.custom_field_groups.create!(
        name: 'User Group', slug: '_user-group', object_class: 'User', objectid: site.id
      )

      expect(site.get_field_groups).not_to include(group)
    end

    it 'excludes a site-placed group owned by another site' do
      other_site = described_class.create!(name: 'Other Site', slug: 'other-site', taxonomy: 'site')
      group = other_site.custom_field_groups.create!(
        name: 'Foreign Group', slug: '_foreign-group', object_class: 'Site', objectid: site.id
      )

      expect(site.get_field_groups).not_to include(group)
    end

    it 'leaves the theme scope unchanged' do
      theme_group = site.custom_field_groups.create!(
        name: 'Theme Group', slug: '_theme-group', object_class: 'Theme', objectid: theme.id
      )

      expect(theme.get_field_groups).to include(theme_group)
      expect(theme.get_field_groups).not_to include(site_group)
    end

    it 'leaves the post type scope unchanged' do
      pt_group = site.custom_field_groups.create!(
        name: 'PT Group', slug: '_pt-group', object_class: 'PostType_Post', objectid: post_type.id
      )

      expect(post_type.get_field_groups('Post')).to include(pt_group)
      expect(post_type.get_field_groups('Post')).not_to include(site_group)
    end
  end

  describe '#add_custom_field_group' do
    let!(:site) { create(:site) }

    # Creation used to run through the unscoped tenancy association, which stamped no object_class
    # and tripped the presence validation on CustomField.
    it 'stamps the placement so the group is readable back' do
      group = site.add_custom_field_group({ name: 'Programmatic Group', slug: '_programmatic-group' })

      expect(group).to be_persisted
      expect(group.object_class).to eql('Site')
      expect(group.objectid).to eq(site.id)
      expect(site.get_field_groups).to include(group)
    end
  end

  describe '#set_field_value' do
    let!(:site) { create(:site) }
    let(:post_type) { site.post_types.first }

    # Resolution used to search every group the site owned, so a slug defined on a post group could
    # win and bind the site's value to a field belonging to another content type.
    it 'binds to the site field when another content type defines the same slug' do
      # The post type group is created first on purpose: resolution ordered by field_order would
      # otherwise pick it, which is exactly the mis-binding this guards against.
      pt_group = site.custom_field_groups.create!(
        name: 'PT Group', slug: '_pt-group', object_class: 'PostType_Post', objectid: post_type.id
      )
      site_group = site.custom_field_groups.create!(
        name: 'Site Group', slug: '_site-group', object_class: 'Site', objectid: site.id
      )
      pt_field = pt_group.add_field({ 'name' => 'Shared', 'slug' => 'shared_slug' }, { 'field_key' => 'text_box' })
      site_field = site_group.add_field({ 'name' => 'Shared', 'slug' => 'shared_slug' },
                                        { 'field_key' => 'text_box' })

      site.set_field_value('shared_slug', 'site value')

      stored = site.custom_field_values.find_by(custom_field_slug: 'shared_slug')
      expect(stored.custom_field_id).to eq(site_field.id)
      expect(stored.custom_field_id).not_to eq(pt_field.id)
    end
  end

  describe 'destroying a site' do
    let!(:site) { create(:site) }

    # get_field_groups no longer covers every group the site owns, so teardown leans on the
    # `dependent: :destroy` tenancy association instead.
    it 'removes every group it owns along with their fields' do
      post_type = site.post_types.first
      theme = site.get_theme
      groups = [
        site.custom_field_groups.create!(name: 'A', slug: '_a', object_class: 'Site', objectid: site.id),
        site.custom_field_groups.create!(name: 'B', slug: '_b', object_class: 'PostType_Post', objectid: post_type.id),
        site.custom_field_groups.create!(name: 'C', slug: '_c', object_class: 'Theme', objectid: theme.id)
      ]
      field_ids = groups.map do |group|
        group.add_field({ 'name' => "Field #{group.slug}", 'slug' => "field#{group.slug}" },
                        { 'field_key' => 'text_box' }).id
      end

      site.destroy

      expect(CamaleonCms::CustomFieldGroup.where(id: groups.map(&:id))).to be_empty
      expect(CamaleonCms::CustomField.unscoped.where(id: field_ids)).to be_empty
    end
  end
end
