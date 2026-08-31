# frozen_string_literal: true

require 'rails_helper'

# Regression (PR #1169 review finding #8, INTRO-TOUR): the admin intro tour reveals the sidebar
# branch each step lives in. AdminLTE 2.4 marks the expanded PARENT LI `menu-open` (2.3 marked the
# `ul.treeview-menu`), so cama_intro_reveal_menu must read the parent li. Reading the ul (as before)
# is always false under 2.4, so it re-clicked the toggle and COLLAPSED the very submenu the step
# points at, alternating open/closed across nested steps.
RSpec.describe 'Admin intro tour submenu reveal', :js do
  init_site

  # Build a 2.4-shaped treeview off-screen, spy on the parent toggle, run the reveal on a nested
  # step, and report how many times the toggle was clicked. 0 = branch left as-is; 1 = toggled.
  def reveal_clicks(parent_open:)
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/"
    page.evaluate_script(<<~JS)
      (function(){
        var open = #{parent_open ? 'true' : 'false'};
        var li = '<li class="treeview' + (open ? ' menu-open' : '') + '">' +
                 '<a class="cama-spy-toggle" href="#">Parent</a>' +
                 '<ul class="treeview-menu"><li id="cama-intro-nested"><a href="/x">child</a></li></ul></li>';
        var $c = jQuery('<ul class="cama-intro-probe"></ul>').append(li).appendTo('body');
        var clicks = 0;
        $c.find('a.cama-spy-toggle').on('click', function(e){ e.preventDefault(); clicks++; });
        cama_intro_reveal_menu(document.getElementById('cama-intro-nested'));
        $c.remove();
        return clicks;
      })()
    JS
  end

  it 'does NOT re-toggle a branch whose parent li is already open' do
    expect(reveal_clicks(parent_open: true)).to eq(0)
  end

  it 'opens a branch whose parent li is closed' do
    expect(reveal_clicks(parent_open: false)).to eq(1)
  end
end
