# frozen_string_literal: true

# An admin can add a repeatable field group several times. Each copy is an instance, and its values
# have the group number of the instance. A theme reads one instance with get_field_values(key, number).
# These examples save the real form, so they test the group numbers that the editor submits.
RSpec.describe 'the group numbers of a repeatable field group', :js do
  init_site

  let(:days_group) do
    @site.custom_field_groups.create!(name: 'Days', slug: '_days', object_class: 'Site', objectid: @site.id,
                                      is_repeat: true)
  end
  let(:notes_group) do
    @site.custom_field_groups.create!(name: 'Notes', slug: '_notes', object_class: 'Site', objectid: @site.id,
                                      is_repeat: true)
  end

  before do
    days_group.add_manual_field(
      { 'name' => 'Days', 'slug' => 'days' },
      { 'field_key' => 'checkboxes',
        'multiple_options' => %w[mon tue].map { |value| { 'title' => value.capitalize, 'value' => value } } }
    )
    notes_group.add_manual_field({ 'name' => 'Note', 'slug' => 'note' }, { 'field_key' => 'text_box' })
    admin_sign_in
  end

  def open_site_settings
    visit "#{cama_root_relative_path}/admin/settings/site?tab=other_config"
    expect(page).to have_css("#custom_field_group_#{notes_group.id} .custom_sortable_grouped")
  end

  def submit_site_settings
    within('#site_settings_form') { click_button 'Submit' }
    expect(page).to have_css('.alert-success')
  end

  def instances(group)
    all("#custom_field_group_#{group.id} > .panel-body > .custom_sortable_grouped")
  end

  def stored(slug)
    @site.reload.custom_field_values.where(custom_field_slug: slug).order(:group_number).pluck(:group_number, :value)
  end

  it 'keeps an instance after an instance with no value at its group number' do
    @site.set_field_value('days', %w[mon], group_number: 1)

    open_site_settings
    submit_site_settings

    expect(stored('days')).to eq([[1, 'mon']])
  end

  it 'keeps the group number of an instance that the admin adds after an empty instance' do
    open_site_settings
    within("#custom_field_group_#{days_group.id}") { find('.duplicate_cutom_group').click }
    within(instances(days_group)[1]) { check 'Mon' }
    submit_site_settings
    open_site_settings
    submit_site_settings

    expect(stored('days')).to eq([[1, 'mon']])
  end

  it 'gives a new instance the highest group number plus 1' do
    @site.set_field_value('note', 'one', group_number: 1)
    @site.set_field_value('note', 'three', group_number: 3)

    open_site_settings
    within("#custom_field_group_#{notes_group.id}") { find('.duplicate_cutom_group').click }
    within(instances(notes_group)[2]) { find('input.input-value').set('four') }
    submit_site_settings

    expect(stored('note')).to eq([[1, 'one'], [3, 'three'], [4, 'four']])
  end

  it 'keeps the group numbers of the other instances after a delete' do
    %w[zero one two].each_with_index { |value, number| @site.set_field_value('note', value, group_number: number) }

    open_site_settings
    within(instances(notes_group)[1]) { find('.header-field-grouped .del').click }
    confirm_dialog
    expect(page).to have_css("#custom_field_group_#{notes_group.id} > .panel-body > .custom_sortable_grouped",
                             count: 2)
    submit_site_settings

    expect(stored('note')).to eq([[0, 'zero'], [2, 'two']])
  end

  # The sortable widget of jQuery UI runs this event after a drag. The example moves the instance in
  # the page and runs the event, because a mouse drag in the browser of the spec is not reliable.
  it 'gives the group numbers to the instances in their new order after a drag' do
    @site.set_field_value('note', 'one', group_number: 1)
    @site.set_field_value('note', 'three', group_number: 3)

    open_site_settings
    page.execute_script(<<~JS, "#custom_field_group_#{notes_group.id}")
      var $group = $(arguments[0]);
      var $instances = $group.find('> .panel-body > .custom_sortable_grouped');
      $instances.last().insertBefore($instances.first());
      $group.trigger('update_custom_group_number');
    JS
    submit_site_settings

    expect(stored('note')).to eq([[1, 'three'], [3, 'one']])
  end

  # The save refuses a group number below 0, so the editor numbers the instances by position.
  it 'numbers the instances by position when a stored group number is below 0' do
    @site.set_field_value('note', 'old', group_number: 0)
    # The validation refuses a group number below 0, so the example writes it without the validation.
    @site.custom_field_values.where(custom_field_slug: 'note').update_all(group_number: -1) # rubocop:disable Rails/SkipsModelValidations
    @site.set_field_value('note', 'one', group_number: 1)

    open_site_settings
    submit_site_settings

    expect(stored('note')).to eq([[0, 'old'], [1, 'one']])
  end
end
