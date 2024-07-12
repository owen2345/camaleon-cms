# frozen_string_literal: true

require 'rails_helper'

describe 'the Shortcodes', :js do
  init_site

  it 'Shortcodes list' do
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/settings/shortcodes"
    expect(page).to have_content('Short Code')
  end
end
