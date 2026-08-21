# frozen_string_literal: true

require 'rails_helper'

# Regression (PR #1169 review finding #11, REMOTE-SOURCE): for a remote (function/URL) autocomplete
# source the jQuery UI autocomplete showed the server's results verbatim, in order. The Awesomplete
# adapter instead re-filtered them with FILTER_CONTAINS, re-sorted by length and capped them, so a
# server match whose label did not literally contain the typed term was dropped; it also mapped no
# autoFocus. The adapter now bypasses the client filter/sort for remote sources and maps autoFocus.
RSpec.describe 'Tag editor remote autocomplete source', :js do
  init_site

  it 'shows server results in order (no re-filter/re-sort) and honors autoFocus' do
    admin_sign_in
    visit "#{cama_root_relative_path}/admin/"

    page.execute_script(<<~JS)
      window.camaTe = $('<input type="text" id="cama-remote-te">').appendTo('body');
      window.camaTe.tagEditor({
        autocomplete: {
          autoFocus: true,
          // jQuery-UI function source: server returns two matches, one NOT containing the term
          source: function(req, cb){ cb(['New York City', 'nyc-area']); }
        }
      });
      window.camaTe.next('.tag-editor').click(); // open an input
      var input = document.querySelector('.tag-editor .tag-editor-tag.active input');
      window.camaTeInput = jQuery(input);
      window.camaTeInput.val('nyc').trigger('input');
    JS

    wait(1) # let the async fetch resolve

    result = page.evaluate_script(<<~JS)
      (function(){
        return {
          items: Array.prototype.map.call(document.querySelectorAll('.awesomplete li'),
                                          function(li){ return li.textContent; }),
          autoFirst: window.camaTeInput.data('awesomplete').autoFirst
        };
      })()
    JS

    # both server results appear, in server order (FILTER_CONTAINS would have dropped "New York City")
    expect(result['items']).to eq(['New York City', 'nyc-area'])
    expect(result['autoFirst']).to be(true)
  end
end
