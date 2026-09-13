# frozen_string_literal: true

require 'rake'

# Audit M13: the scan_content task must report field_attrs values, not only editor/URI values, so an
# operator cleaning up pre-gate data is not handed a false all-clear for the subtlest field type.
RSpec.describe 'camaleon_cms:security:scan_content Rake task', type: :task do
  before(:all) do # rubocop:disable RSpec/BeforeAfterAll
    Rails.application.load_tasks
  end

  after(:all) do # rubocop:disable RSpec/BeforeAfterAll
    Rake::Task['camaleon_cms:security:scan_content'].clear
  end

  let(:task) { Rake::Task['camaleon_cms:security:scan_content'] }
  let(:site) { CamaleonCms::Site.first }
  let(:post_type) { site.post_types.find_by(slug: 'post') }
  let(:post_record) { create(:post, post_type: post_type) }
  let(:group) do
    CamaleonCms::CustomFieldGroup.create!(name: 'Scan', slug: 'scan-fields', object_class: 'PostType_Post',
                                          objectid: post_type.id, site: site)
  end

  before { task.reenable }

  it 'flags a stored field_attrs value that would fail the gate' do
    field = group.add_manual_field({ name: 'Specs', slug: 'scan_specs' }, { field_key: 'field_attrs' })
    post_record.set_field_value('scan_specs', { attr: 'a', value: 'ok' }.to_json, field_id: field.id)
    row = post_record.custom_field_values.find_by(custom_field_slug: 'scan_specs')
    # simulate a dangerous value stored before the gate existed
    row.update_column(:value, { attr: 'a', value: '<script>alert(1)</script>' }.to_json) # rubocop:disable Rails/SkipsModelValidations

    expect { task.invoke }
      .to output(/Custom-field value id=#{row.id}.*field_attrs.*would be rejected/m).to_stdout
  end

  it 'does not flag a benign field_attrs value' do
    field = group.add_manual_field({ name: 'OK', slug: 'scan_ok' }, { field_key: 'field_attrs' })
    post_record.set_field_value('scan_ok', { attr: 'a', value: 'plain' }.to_json, field_id: field.id)
    row = post_record.custom_field_values.find_by(custom_field_slug: 'scan_ok')

    expect { task.invoke }.not_to output(/id=#{row.id}.*would be rejected/m).to_stdout
  end

  # A post type's decorator class option is checked at save; a value stored before the check is
  # ignored at render and listed here (OpenSpec: post-decorator-class-integrity).
  it 'flags a post type whose stored decorator class is not a post decorator' do
    meta = post_type.metas.find_by!(key: '_default')
    meta.update!(value: JSON.parse(meta.value).merge('cama_post_decorator_class' => 'Object').to_json)

    expect { task.invoke }
      .to output(/Post type id=#{post_type.id}.*cama_post_decorator_class 'Object'/m).to_stdout
  end

  it 'does not flag a post type whose decorator class is a post decorator' do
    post_type.set_option('cama_post_decorator_class', 'CamaleonCms::PostDecorator')

    expect { task.invoke }.not_to output(/Post type id=#{post_type.id}/m).to_stdout
  end
end
