# frozen_string_literal: true

require 'rails_helper'

# Regression (PR #1169 review finding #14, ICON-CONTRAST): panel-control icon contrast was decided
# at runtime by cama_fix_panel_icon_contrast (measure the heading luma, toggle .panel-controls-light)
# fighting an equal-specificity CSS rule that painted every colour variant white. The result: the
# white rule was dead for the four pastel variants, the ready-time pass restyled every plain panel's
# controls admin-wide, and .panel-controls-light .fa greyed the .text-danger delete icon. It is now
# a single static rule: panel-primary (the only dark heading) gets white icons; everything else
# keeps the default dark icons, and the JS pass / .panel-controls-light class are gone.
RSpec.describe 'Admin panel-controls icon contrast', :js do
  init_site

  it 'is decided statically: white only on panel-primary, no runtime luma class' do
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/"

    result = page.evaluate_script(<<~JS)
      (function(){
        function panel(cls, id){
          return '<div class="panel ' + cls + '"><div class="panel-heading"><ul class="panel-controls">' +
                 '<li><a id="' + id + '" href="#"><i class="fa fa-cog"></i></a></li></ul></div></div>';
        }
        var html = '<div id="cama-contrast-probe">' +
          panel('panel-primary', 'pc-primary') +
          panel('panel-success', 'pc-success') +
          panel('', 'pc-default') + '</div>';
        jQuery(html).appendTo('#admin_content');
        function color(id){ return getComputedStyle(document.getElementById(id)).color; }
        var r = {
          primary: color('pc-primary'),
          success: color('pc-success'),
          default: color('pc-default'),
          light_class_count: jQuery('#cama-contrast-probe a.panel-controls-light').length,
          fn_defined: (typeof cama_fix_panel_icon_contrast)
        };
        jQuery('#cama-contrast-probe').remove();
        return r;
      })()
    JS

    expect(result['primary']).to eq('rgb(255, 255, 255)')     # dark heading -> white icons
    expect(result['success']).not_to eq('rgb(255, 255, 255)') # pastel heading -> default dark icons
    expect(result['default']).not_to eq('rgb(255, 255, 255)') # plain panel keeps its own styling
    expect(result['light_class_count']).to eq(0)              # no runtime .panel-controls-light toggling
    expect(result['fn_defined']).to eq('undefined')           # the luma helper is removed
  end
end
