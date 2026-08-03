# frozen_string_literal: true

require 'rails_helper'

describe 'the Themes', :js do
  init_site

  it 'Themes list' do
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/appearances/themes"
    expect(page).to have_css('#themes_page')
    within '#themes_page' do
      first('.preview_link').click
    end
    # wait_for_ajax
    # page.within_frame '#ow_inline_modal_iframe' do
    #   page.should have_selector 'body'
    # end
  end

  # Activating camaleon_first runs its on_active hook in controller context, where the
  # helper.capture-based field defaults raised NoMethodError after already switching the theme.
  it 'activates the bundled camaleon_first theme without error' do
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/appearances/themes?set=camaleon_first"

    expect(page).to have_css('#themes_page')
    expect(CamaleonCms::Site.first.get_option('_theme')).to eq('camaleon_first')
  end
end
