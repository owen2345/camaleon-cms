# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'user_field_groups Rake task', type: :task do
  before(:all) do # rubocop:disable RSpec/BeforeAfterAll
    Rails.application.load_tasks
  end

  after(:all) do # rubocop:disable RSpec/BeforeAfterAll
    Rake::Task['camaleon_cms:demodulize_user_field_groups'].clear
  end

  describe 'camaleon_cms:demodulize_user_field_groups' do
    let(:task) { Rake::Task['camaleon_cms:demodulize_user_field_groups'] }
    let(:site) { Cama::Site.first }

    before { task.reenable }

    def stub_user_model(name)
      allow(PluginRoutes).to receive(:static_system_info).and_return(
        PluginRoutes.static_system_info.merge('user_model' => name)
      )
    end

    # Groups were written by the pre-fix settings form under the raw user_model config string;
    # build them unscoped to keep the spec honest about what it repairs.
    def create_group(attrs)
      CamaleonCms::CustomField.unscoped.create!({ name: 'User Group', slug: '_user-group' }.merge(attrs))
    end

    it 're-keys a group placement stored under the configured qualified name, idempotently' do
      stub_user_model('Admin::User')
      group = create_group(object_class: 'Admin::User', objectid: site.id, parent_id: site.id)

      # Operators run this once from a console; the summary must land on stdout, not in the log.
      expect { task.invoke }.to output(/Re-keyed 1 user field group\(s\) from 'Admin::User' to 'User'/).to_stdout

      expect(group.reload.object_class).to eq('User')

      task.reenable
      expect { task.invoke }.not_to raise_error
      expect(group.reload.object_class).to eq('User')
    end

    it 'makes the re-keyed group readable through the user field-group read again' do
      stub_user_model('Admin::User')
      stub_const('Admin::User', Class.new(::CamaleonRecord) { self.table_name = CamaleonCms::User.table_name })
      Admin::User.include(CamaleonCms::CustomFieldsRead)
      group = create_group(object_class: 'Admin::User', objectid: site.id, parent_id: site.id)
      expect(Admin::User.new.get_user_field_groups(site).map(&:id)).not_to include(group.id)

      task.invoke

      expect(Admin::User.new.get_user_field_groups(site).map(&:id)).to include(group.id)
    end

    it 'leaves other placements and the group field rows untouched' do
      stub_user_model('Admin::User')
      site_group = create_group(object_class: 'Site', objectid: site.id, parent_id: site.id, slug: '_site-group')
      qualified = create_group(object_class: 'Admin::User', objectid: site.id, parent_id: site.id)
      field = CamaleonCms::CustomField.unscoped.create!(
        name: 'Rating', slug: 'rating', object_class: '_fields', parent_id: qualified.id
      )

      task.invoke

      expect(site_group.reload.object_class).to eq('Site')
      expect(field.reload.object_class).to eq('_fields')
      expect(field.reload.parent_id).to eq(qualified.id)
    end

    it 'is a no-op when the configured user model is not namespaced' do
      stray = create_group(object_class: 'Admin::User', objectid: site.id, parent_id: site.id)

      expect { task.invoke }.to output(/Nothing to re-key/).to_stdout

      expect(stray.reload.object_class).to eq('Admin::User')
    end
  end
end
