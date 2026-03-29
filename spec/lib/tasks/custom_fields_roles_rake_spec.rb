# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'camaleon_cms:backfill_custom_fields_permission', type: :task do
  let(:task_name) { 'camaleon_cms:backfill_custom_fields_permission' }
  let(:task) { Rake::Task[task_name] }

  before(:all) do # rubocop:disable RSpec/BeforeAfterAll
    Rails.application.load_tasks unless Rake::Task.task_defined?('camaleon_cms:backfill_custom_fields_permission')
  end

  after(:all) do # rubocop:disable RSpec/BeforeAfterAll
    Rake::Task['camaleon_cms:backfill_custom_fields_permission'].clear
  end

  before { task.reenable }

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
