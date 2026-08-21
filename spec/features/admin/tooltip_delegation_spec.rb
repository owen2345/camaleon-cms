# frozen_string_literal: true

require 'rails_helper'

# Regression (PR #1169 review finding #13, TOOLTIP-DELEGATION): AdminLTE 2.3 installed a
# body-delegated Bootstrap tooltip for every [data-toggle="tooltip"], so triggers inserted later
# via AJAX (e.g. cama_contact_form's dynamically added field rows) still got a tooltip. AdminLTE
# 2.4 dropped it, and Camaleon's own init runs once, only inside #admin_content, only for
# a/button. The admin ready handler now restores the delegated init.
RSpec.describe 'Admin tooltip delegation', :js do
  init_site

  it 'shows a tooltip for a [data-toggle=tooltip] element inserted after load' do
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/"

    # simulate an AJAX-injected control (no eager .tooltip() call of its own)
    page.execute_script(
      "jQuery('<a id=\"cama-late-tip\" data-toggle=\"tooltip\" title=\"Late tip\" href=\"#\">x</a>')" \
      ".appendTo('body');"
    )

    find('#cama-late-tip').hover

    expect(page).to have_css('.tooltip .tooltip-inner', text: 'Late tip')
  end
end
