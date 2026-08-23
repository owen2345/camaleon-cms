# frozen_string_literal: true

require 'rake'

RSpec.describe 'site_custom_field_groups Rake task', type: :task do
  before(:all) do # rubocop:disable RSpec/BeforeAfterAll
    Rails.application.load_tasks
  end

  after(:all) do # rubocop:disable RSpec/BeforeAfterAll
    Rake::Task['camaleon_cms:backfill_site_field_group_objectid'].clear
  end

  describe 'camaleon_cms:backfill_site_field_group_objectid' do
    let(:task) { Rake::Task['camaleon_cms:backfill_site_field_group_objectid'] }
    let!(:site) { create(:site) }
    let(:post_type) { site.post_types.first }

    before { task.reenable }

    it 'reports a summary on stdout for the operator running it' do
      expect { task.invoke }.to output(/Summary:/).to_stdout
    end

    # object_class has a presence validation but objectid does not, so a group with a NULL objectid
    # is constructible. Build it unscoped to keep the spec honest about what it repairs.
    def create_group(attrs)
      CamaleonCms::CustomField.unscoped.create!({ name: 'Legacy Group', slug: '_legacy-group' }.merge(attrs))
    end

    it 'gives a site-placed group without an objectid the id of the site that owns it' do
      group = create_group(object_class: 'Site', objectid: nil, parent_id: site.id)

      task.invoke

      expect(group.reload.objectid).to eq(site.id)
    end

    it 'makes the repaired group visible on its own site again' do
      group = create_group(object_class: 'Site', objectid: nil, parent_id: site.id)
      expect(site.get_field_groups.map(&:id)).not_to include(group.id)

      task.invoke

      expect(site.get_field_groups.map(&:id)).to include(group.id)
    end

    it 'leaves site-placed groups that already have an objectid untouched' do
      group = create_group(object_class: 'Site', objectid: site.id, parent_id: site.id, slug: '_already-placed')

      task.invoke

      expect(group.reload.objectid).to eq(site.id)
    end

    it 'leaves groups of other placement classes untouched' do
      theme_group = create_group(object_class: 'Theme', objectid: nil, parent_id: site.id, slug: '_theme-legacy')
      pt_group = create_group(object_class: 'PostType_Post', objectid: post_type.id, parent_id: site.id,
                              slug: '_pt-legacy')

      task.invoke

      expect(theme_group.reload.objectid).to be_nil
      expect(pt_group.reload.objectid).to eq(post_type.id)
    end

    it 'skips a site-placed group that has no owning site' do
      group = create_group(object_class: 'Site', objectid: nil, parent_id: nil, slug: '_orphan')

      task.invoke

      expect(group.reload.objectid).to be_nil
    end

    it 'continues processing remaining groups when one update fails' do
      broken = create_group(object_class: 'Site', objectid: nil, parent_id: site.id, slug: '_broken')
      healthy = create_group(object_class: 'Site', objectid: nil, parent_id: site.id, slug: '_healthy')

      allow_any_instance_of(CamaleonCms::CustomField).to receive(:update_column).and_wrap_original do |original, *args|
        raise StandardError, 'forced failure' if original.receiver.slug == '_broken'

        original.call(*args)
      end

      expect { task.invoke }.not_to raise_error

      expect(healthy.reload.objectid).to eq(site.id)
      expect(broken.reload.objectid).to be_nil
    end
  end
end
