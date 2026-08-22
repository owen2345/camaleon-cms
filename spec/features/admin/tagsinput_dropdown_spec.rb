# frozen_string_literal: true

require 'rails_helper'

# Regression (PR #1169 review finding #12, TAGSINPUT-CLIP/CALLBACKS): the tagsInput Awesomplete
# adapter mounted its dropdown inside the fixed-height, overflow-y:auto holder, so suggestions were
# clipped/scrolled inside the tag box (jQuery UI's menu floated over the page); and it consumed only
# source/minChars, silently dropping the autocomplete.select callback the old bundle forwarded to
# jQuery UI. The holder now unclips while focused, and the select callback is wired.
RSpec.describe 'jQuery tagsInput dropdown and select callback', :js do
  init_site

  it 'unclips the holder while focused and wires the autocomplete select callback' do
    admin_sign_in
    visit "#{cama_root_relative_path}/admin"
    wait(2)

    result = page.evaluate_script(<<~JS)
      (function() {
        var out = {}, selected = null;
        var $t = jQuery('<input id="td_probe">').appendTo('body');
        $t.tagsInput({ autocomplete: {
          source: ['alpha', 'alpine'],
          select: function(ev, ui) { selected = ui.item.value; return false; } // veto the default add
        }});
        var fake = jQuery('#td_probe_tag');
        var holder = jQuery('#td_probe_tagsinput');

        // focus unclips the holder so the dropdown can overflow it
        fake.trigger('focus');
        out.has_editing_class = holder.hasClass('tagsinput-editing');
        out.overflow_visible = getComputedStyle(holder[0]).overflowY === 'visible';

        // selectcomplete invokes the user select callback; returning false prevents the tag add
        var ev = new CustomEvent('awesomplete-selectcomplete');
        ev.text = { value: 'alpine', label: 'alpine' };
        fake[0].dispatchEvent(ev);
        out.select_called = selected === 'alpine';
        out.select_veto = $t.val() === '' && holder.find('.tag').length === 0;

        // blur re-clips
        fake.trigger('blur');
        out.reclipped = !holder.hasClass('tagsinput-editing');

        var aw = fake.data('awesomplete'); if (aw) aw.destroy();
        jQuery('#td_probe, #td_probe_tagsinput').remove();
        return out;
      })()
    JS

    failures = result.reject { |_check, value| value == true }
    expect(failures).to be_empty, "tagsInput dropdown/select checks that did not pass: #{failures.keys.join(', ')}"
  end
end
