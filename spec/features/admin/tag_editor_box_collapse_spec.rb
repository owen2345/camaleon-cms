# frozen_string_literal: true

require 'rails_helper'

# Regression (PR #1169 review finding #6, TE-CSS-COLLAPSE): the tag editor box (.tag-editor) draws
# its height entirely from the block-formatting context that `overflow: hidden` establishes -- every
# child (the tag pills) is floated. While a tag input is open the script adds .tag-editor-editing,
# which set `overflow: visible` (so the Awesomplete dropdown can escape) and thereby dropped the BFC,
# collapsing the bordered box to a 2px line. `display: flow-root` keeps a BFC while still allowing
# overflow, so the box keeps its height.
RSpec.describe 'Tag editor box while editing', :js do
  init_site

  it 'does not collapse when the editing class is applied' do
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/"

    heights = page.evaluate_script(<<~JS)
      (function(){
        var html = '<ul class="tag-editor" id="cama-te">' +
                   '<li><div class="tag-editor-tag">alpha</div></li>' +
                   '<li><div class="tag-editor-tag">beta</div></li></ul>';
        var el = jQuery(html).appendTo('body')[0];
        var closed = el.offsetHeight;
        jQuery(el).addClass('tag-editor-editing');
        var editing = el.offsetHeight;
        jQuery(el).remove();
        return { closed: closed, editing: editing };
      })()
    JS

    expect(heights['closed']).to be > 10
    # without display:flow-root the editing box would collapse to ~2px (border only)
    expect(heights['editing']).to be_within(2).of(heights['closed'])
  end
end
