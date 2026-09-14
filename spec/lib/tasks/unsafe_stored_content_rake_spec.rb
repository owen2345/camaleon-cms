# frozen_string_literal: true

# The scan_content task must report every stored value today's gates would refuse -- field_attrs
# values as well as editor/URI values, post summaries, templates and layouts outside the site's
# theme, options rows that are not JSON objects -- so an operator cleaning up pre-gate data is not
# handed a false all-clear. Nothing stored is rewritten; listing is the only remedy for history.
RSpec.describe 'camaleon_cms:security:scan_content Rake task', type: :task do
  before(:all) { Rails.application.load_tasks } # rubocop:disable RSpec/BeforeAfterAll

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

  before do
    task.reenable
    allow(Rails.env).to receive(:test?).and_return(false)
  end

  # A decorator class option stored without passing the save-time check.
  def store_decorator_option(target, value)
    meta = target.metas.find_by!(key: '_default')
    meta.update!(value: JSON.parse(meta.value).merge('cama_post_decorator_class' => value).to_json)
  end

  # Every id in the report patterns ends at a word boundary, so a line about another record whose id
  # starts with the same digits neither satisfies nor breaks an expectation.
  it 'flags a stored field_attrs value that would fail the gate' do
    field = group.add_manual_field({ name: 'Specs', slug: 'scan_specs' }, { field_key: 'field_attrs' })
    post_record.set_field_value('scan_specs', { attr: 'a', value: 'ok' }.to_json, field_id: field.id)
    row = post_record.custom_field_values.find_by(custom_field_slug: 'scan_specs')
    # simulate a dangerous value stored before the gate existed
    row.update_column(:value, { attr: 'a', value: '<script>alert(1)</script>' }.to_json) # rubocop:disable Rails/SkipsModelValidations

    expect { task.invoke }
      .to output(/Custom-field value id=#{row.id}\b.*field_attrs.*would be rejected/m).to_stdout
  end

  it 'does not flag a benign field_attrs value' do
    field = group.add_manual_field({ name: 'OK', slug: 'scan_ok' }, { field_key: 'field_attrs' })
    post_record.set_field_value('scan_ok', { attr: 'a', value: 'plain' }.to_json, field_id: field.id)
    row = post_record.custom_field_values.find_by(custom_field_slug: 'scan_ok')

    expect { task.invoke }.not_to output(/Custom-field value id=#{row.id}\b.*would be rejected/).to_stdout
  end

  # A post type's decorator class option is checked at save; a value stored before the check is
  # ignored at render and listed here (OpenSpec: post-decorator-class-integrity).
  it 'flags a post type whose stored decorator class is not a post decorator' do
    store_decorator_option(post_type, 'Object')

    expect { task.invoke }
      .to output(/Post type id=#{post_type.id}\b.*cama_post_decorator_class 'Object'/).to_stdout
  end

  it 'lists a stored decorator name that cannot be loaded and finishes the scan' do
    store_decorator_option(post_type, 'ENV::X')

    expect { task.invoke }
      .to output(/Post type id=#{post_type.id}\b.*cama_post_decorator_class 'ENV::X'.*Done\./m).to_stdout
  end

  it 'lists a post type whose options cannot be read and scans the post types after it' do
    unreadable = create(:post_type, data_options: { has_category: false })
    later = create(:post_type, data_options: { has_category: false })
    unreadable.metas.find_by!(key: '_default').update!(value: '[]')
    store_decorator_option(later, 'Object')

    expect { task.invoke }
      .to output(/Post type id=#{unreadable.id}\b.*could not be read.*Post type id=#{later.id}\b.*'Object'.*Done\./m)
      .to_stdout
  end

  it 'does not flag a post type whose decorator class is a post decorator' do
    post_type.set_option('cama_post_decorator_class', 'CamaleonCms::PostDecorator')

    expect { task.invoke }.not_to output(/Post type id=#{post_type.id}\b/).to_stdout
  end

  it 'does not flag a post type whose decorator option is blank' do
    store_decorator_option(post_type, '')

    expect { task.invoke }.not_to output(/Post type id=#{post_type.id}\b/).to_stdout
  end

  # The post save holds a non-admin's template, layout and default views to the editor's lists; a
  # value stored before that rule (an admin view, say) still renders and is listed here against the
  # site's theme view files.
  describe 'post templates, layouts and default views' do
    it 'flags a post whose stored template is not a theme view' do
      post_record.set_meta('template', 'camaleon_cms/admin/settings/site')

      expect { task.invoke }
        .to output(%r{Post id=#{post_record.id}\b.*template 'camaleon_cms/admin/settings/site' is not a view}).to_stdout
    end

    it 'flags a post whose default layout option is not a theme layout' do
      post_record.set_option('default_layout', 'camaleon_cms/admin')

      expect { task.invoke }
        .to output(%r{Post id=#{post_record.id}\b.*default_layout 'camaleon_cms/admin' is not a view}).to_stdout
    end

    it 'does not flag a post whose layout is one of the theme layouts' do
      post_record.set_meta('layout', 'index')

      expect { task.invoke }.not_to output(/Post id=#{post_record.id}\b/).to_stdout
    end

    it 'flags a post type whose default template is not a theme view' do
      post_type.set_option('default_template', 'camaleon_cms/admin/settings/site')

      expect { task.invoke }
        .to output(/Post type id=#{post_type.id}\b.*default_template 'camaleon_cms.*is not a view/).to_stdout
    end
  end

  describe 'options rows and summaries' do
    it 'lists a post whose options row is not an object and scans the posts after it' do
      post_record.set_meta('_default', 'corrupt')
      later = create(:post, post_type: post_type)
      later.set_meta('template', 'camaleon_cms/admin/settings/site')

      expect { task.invoke }
        .to output(/Post id=#{post_record.id}\b.*options could not be read.*Post id=#{later.id}\b.*template.*Done\./m)
        .to_stdout
    end

    it 'flags a summary the content scan would refuse' do
      post_record.set_meta('summary', 'Intro <script>alert(1)</script>')

      expect { task.invoke }.to output(/Post id=#{post_record.id}\b.*summary would be rejected/).to_stdout
    end

    it 'does not flag a summary within the content allowlist' do
      post_record.set_meta('summary', 'Plain <b>bold</b> summary')

      expect { task.invoke }.not_to output(/Post id=#{post_record.id}\b/).to_stdout
    end
  end
end
