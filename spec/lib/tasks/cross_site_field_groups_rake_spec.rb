# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'cross_site_field_groups Rake task', type: :task do
  before(:all) do # rubocop:disable RSpec/BeforeAfterAll
    Rails.application.load_tasks
  end

  after(:all) do # rubocop:disable RSpec/BeforeAfterAll
    Rake::Task['camaleon_cms:rehome_cross_site_field_groups'].clear
  end

  describe 'camaleon_cms:rehome_cross_site_field_groups' do
    let(:task) { Rake::Task['camaleon_cms:rehome_cross_site_field_groups'] }
    let!(:owner_site) { create(:site) }
    let(:victim_site) { CamaleonCms::Site.create!(name: 'Victim', slug: 'victim-rehome', taxonomy: 'site') }

    before { task.reenable }

    def injected_group(object_class, objectid, slug)
      owner_site.custom_field_groups.create!(
        name: "Injected #{slug}", slug: slug, object_class: object_class, objectid: objectid
      )
    end

    it "moves a group placed on another site's theme to that site" do
      theme = victim_site.get_theme
      group = injected_group('Theme', theme.id, '_inj-theme')

      task.invoke

      expect(group.reload.parent_id).to eq(victim_site.id)
    end

    it 'makes the group visible to the affected site and gone from the injector' do
      theme = victim_site.get_theme
      group = injected_group('Theme', theme.id, '_inj-theme')

      task.invoke

      expect(victim_site.custom_field_groups.reload).to include(group)
      expect(owner_site.custom_field_groups.reload).not_to include(group)
    end

    it "moves a group placed on another site's nav menu, post type and plugin" do
      menu = victim_site.nav_menus.create!(name: 'Victim Menu', slug: 'victim-menu')
      post_type = victim_site.post_types.create!(name: 'Victim PT', slug: 'victim-pt')
      plugin = victim_site.get_plugin('victim_plugin')
      groups = [
        injected_group('NavMenu', menu.id, '_inj-menu'),
        injected_group('PostType_Post', post_type.id, '_inj-pt'),
        injected_group('Plugin', plugin.id, '_inj-plugin')
      ]

      task.invoke

      expect(groups.map { |g| g.reload.parent_id }).to all(eq(victim_site.id))
    end

    it 'leaves correctly owned groups untouched' do
      own_theme = owner_site.get_theme
      own = injected_group('Theme', own_theme.id, '_own-theme')
      site_placed = injected_group('Site', owner_site.id, '_own-site')

      task.invoke

      expect(own.reload.parent_id).to eq(owner_site.id)
      expect(site_placed.reload.parent_id).to eq(owner_site.id)
    end

    it 'leaves a group whose placement target no longer exists alone' do
      group = injected_group('Theme', 999_999, '_dangling')

      task.invoke

      expect(group.reload.parent_id).to eq(owner_site.id)
      expect(CamaleonCms::CustomFieldGroup.where(id: group.id)).to be_present
    end

    it 'does not delete anything' do
      theme = victim_site.get_theme
      injected_group('Theme', theme.id, '_inj-theme')
      injected_group('Theme', 999_999, '_dangling')

      expect { task.invoke }.not_to(change { CamaleonCms::CustomFieldGroup.unscoped.count })
    end

    it 'continues processing remaining groups when one update fails' do
      theme = victim_site.get_theme
      menu = victim_site.nav_menus.create!(name: 'Victim Menu', slug: 'victim-menu')
      broken = injected_group('Theme', theme.id, '_broken')
      healthy = injected_group('NavMenu', menu.id, '_healthy')

      allow_any_instance_of(CamaleonCms::CustomField).to receive(:update_column).and_wrap_original do |original, *args|
        raise StandardError, 'forced failure' if original.receiver.slug == '_broken'

        original.call(*args)
      end

      expect { task.invoke }.not_to raise_error

      expect(healthy.reload.parent_id).to eq(victim_site.id)
      expect(broken.reload.parent_id).to eq(owner_site.id)
    end
  end
end
