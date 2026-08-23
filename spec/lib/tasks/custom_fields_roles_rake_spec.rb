# frozen_string_literal: true

require 'rake'

RSpec.describe 'custum_fields_roles Rake task', type: :task do
  before(:all) do # rubocop:disable RSpec/BeforeAfterAll
    Rails.application.load_tasks
  end

  after(:all) do # rubocop:disable RSpec/BeforeAfterAll
    Rake::Task['camaleon_cms:backfill_custom_fields_permission'].clear
    Rake::Task['camaleon_cms:backfill_select_eval_permission'].clear
  end

  describe 'camaleon_cms:backfill_custom_fields_permission' do
    let(:task_name) { 'camaleon_cms:backfill_custom_fields_permission' }
    let(:task) { Rake::Task[task_name] }

    before { task.reenable }

    it 'reports progress on stdout for the operator running it' do
      expect { task.invoke }.to output(/Backfilling custom_fields manager permission/).to_stdout
    end

    it 'adds custom_fields permission when manager meta is missing' do
      site = create(:site)
      role = site.user_roles.create!(name: 'Needs Backfill', slug: 'needs_backfill')
      key = "_manager_#{role.parent_id}"

      expect(role.metas.where(key: key)).to be_empty

      task.invoke

      expect(CamaleonCms::UserRole.find(role.id).get_meta(key)).to include('custom_fields' => 1)
    end

    it 'does not overwrite manager meta when custom_fields is already present' do
      site = create(:site)
      role = site.user_roles.create!(name: 'Already Permitted', slug: 'already_permitted')
      key = "_manager_#{role.parent_id}"
      original_meta = { 'custom_fields' => 1, 'themes' => 1 }
      role.set_meta(key, original_meta)

      task.invoke

      expect(CamaleonCms::UserRole.find(role.id).get_meta(key)).to eq(original_meta)
    end

    it 'normalizes non-hash manager meta values before backfilling' do
      site = create(:site)
      role = site.user_roles.create!(name: 'Legacy Meta', slug: 'legacy_meta')
      key = "_manager_#{role.parent_id}"
      role.set_meta(key, 'legacy-value')

      task.invoke

      expect(CamaleonCms::UserRole.find(role.id).get_meta(key)).to eq('custom_fields' => 1)
    end

    it 'continues processing other roles when one role fails to update' do
      site = create(:site)
      broken_role = site.user_roles.create!(name: 'Broken Role', slug: 'broken_role')
      healthy_role = site.user_roles.create!(name: 'Healthy Role', slug: 'healthy_role')
      broken_key = "_manager_#{broken_role.parent_id}"
      healthy_key = "_manager_#{healthy_role.parent_id}"

      allow(CamaleonCms::UserRole).to receive(:find_each).and_yield(broken_role).and_yield(healthy_role)
      allow(broken_role).to receive(:set_meta)
        .with(broken_key, hash_including('custom_fields' => 1))
        .and_raise(StandardError, 'forced failure')

      expect { task.invoke }.not_to raise_error

      expect(CamaleonCms::UserRole.find(healthy_role.id).get_meta(healthy_key)).to include('custom_fields' => 1)
      expect(CamaleonCms::UserRole.find(broken_role.id).metas.where(key: broken_key)).to be_empty
    end
  end

  describe 'camaleon_cms:backfill_select_eval_permission' do
    let(:task_name) { 'camaleon_cms:backfill_select_eval_permission' }
    let(:task) { Rake::Task[task_name] }

    before { task.reenable }

    it 'reports a summary on stdout for the operator running it' do
      expect { task.invoke }.to output(/Summary:/).to_stdout
    end

    it 'adds select_eval permission for admin roles with term_group -1' do
      # slugs are unique per parent, so the scenarios below reuse the shared
      # site's default admin role instead of creating a second admin-slugged one
      role = CamaleonCms::UserRole.find_by!(slug: 'admin', term_group: -1)
      key = "_manager_#{role.parent_id}"
      role.set_meta(key, { themes: 1 })

      task.invoke

      updated_meta = CamaleonCms::UserRole.find(role.id).get_meta(key, {})
      expect(updated_meta[:themes]).to eq(1)
      expect(updated_meta[:select_eval]).to eq(1)
    end

    it 'skips admin roles that already have select_eval permission' do
      role = CamaleonCms::UserRole.find_by!(slug: 'admin', term_group: -1)
      key = "_manager_#{role.parent_id}"
      role.set_meta(key, { select_eval: 1, users: 1 })

      task.invoke

      updated_meta = CamaleonCms::UserRole.find(role.id).get_meta(key, {})
      expect(updated_meta[:select_eval]).to eq(1)
      expect(updated_meta[:users]).to eq(1)
      expect(updated_meta.keys.map(&:to_s)).to match_array(%w[select_eval users])
    end

    it 'does not update roles outside the admin term_group -1 scope' do
      admin_editable = CamaleonCms::UserRole.find_by!(slug: 'admin').tap { |r| r.update!(term_group: nil) }
      editor_role = CamaleonCms::UserRole.find_by!(slug: 'editor')
      admin_key = "_manager_#{admin_editable.parent_id}"
      editor_key = "_manager_#{editor_role.parent_id}"
      # the default roles carry installed metas; the scenario needs roles
      # without select_eval to prove the task leaves them alone
      admin_editable.set_meta(admin_key, {})
      editor_role.set_meta(editor_key, {})

      task.invoke

      expect(CamaleonCms::UserRole.find(admin_editable.id).get_meta(admin_key, {})[:select_eval]).to be_nil
      expect(CamaleonCms::UserRole.find(editor_role.id).get_meta(editor_key, {})[:select_eval]).to be_nil
    end

    it 'continues processing remaining admin roles when one update fails' do
      # the admin scope is stubbed below, so the fixtures only need to be two
      # distinct roles — duplicate admin slugs under one parent are now invalid
      site = create(:site)
      broken_role = site.user_roles.create!(name: 'Broken Admin', slug: 'broken-admin', term_group: -1)
      healthy_role = site.user_roles.create!(name: 'Healthy Admin', slug: 'healthy-admin', term_group: -1)
      broken_key = "_manager_#{broken_role.parent_id}"
      healthy_key = "_manager_#{healthy_role.parent_id}"

      relation = instance_double(ActiveRecord::Relation)
      allow(CamaleonCms::UserRole).to receive(:where).with(slug: 'admin', term_group: -1).and_return(relation)
      allow(relation).to receive(:find_each).and_yield(broken_role).and_yield(healthy_role)
      allow(broken_role).to receive(:set_meta).with(broken_key, hash_including(select_eval: 1))
                                              .and_raise(StandardError, 'forced failure')

      expect { task.invoke }.not_to raise_error

      expect(CamaleonCms::UserRole.find(healthy_role.id).get_meta(healthy_key, {})[:select_eval]).to eq(1)
      expect(CamaleonCms::UserRole.find(broken_role.id).metas.where(key: broken_key)).to be_empty
    end
  end
end
