# frozen_string_literal: true

# The checkboxes partial keeps the `values[]` name of its inputs. The admin JavaScript renames the
# inputs of the other fields to `values[<index>]`. The request specs build that list by hand. These
# examples submit the real form, so they fail when the partial, the JavaScript or the permit changes
# the shape.
RSpec.describe 'the checkboxes custom field', :js do
  init_site

  before do
    group = @site.custom_field_groups.create!(name: 'Site Group', slug: '_site-group', object_class: 'Site',
                                              objectid: @site.id)
    group.add_manual_field(
      { 'name' => 'Colors', 'slug' => 'colors' },
      { 'field_key' => 'checkboxes',
        'multiple_options' => %w[1 2 3].map { |value| { 'title' => "Option #{value}", 'value' => value } } }
    )
    admin_sign_in
  end

  def save_site_settings
    visit "#{cama_root_relative_path}/admin/settings/site?tab=other_config"
    within '#site_settings_form' do
      yield
      click_button 'Submit'
    end
    expect(page).to have_css('.alert-success')
    @site.reload.get_field_values('colors')
  end

  it 'stores the options that the admin checks' do
    stored = save_site_settings do
      check 'Option 1'
      check 'Option 3'
    end

    expect(stored).to eq(%w[1 3])
  end

  it 'shows the stored options as checked and removes the options that the admin unchecks' do
    @site.set_field_value('colors', %w[1 3])

    stored = save_site_settings do
      expect(page).to have_checked_field('Option 1')
      expect(page).to have_unchecked_field('Option 2')
      expect(page).to have_checked_field('Option 3')
      uncheck 'Option 1'
    end

    expect(stored).to eq(%w[3])

    stored = save_site_settings do
      expect(page).to have_unchecked_field('Option 1')
      expect(page).to have_checked_field('Option 3')
      uncheck 'Option 3'
    end

    expect(stored).to be_empty
  end
end
