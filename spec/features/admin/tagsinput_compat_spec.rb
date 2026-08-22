# frozen_string_literal: true

require 'rails_helper'

# Regression (PR #1169 review, TAGSINPUT/S3/AL3/A1-7 and finding #11): the jQuery 3 rework ported
# the xoxco tagsinput autocomplete branch to Awesomplete. $.fn.tagsInput has no in-repo caller but
# ships to downstream plugins via the admin manifest, so the port must keep the public API and honor
# the jQuery-UI autocomplete source contract the old bundle offered:
#   * source may be an array, a function invoked as source({term}, response) or a URL string fetched
#     with a `term` parameter; autocomplete.minLength maps to Awesomplete minChars
#   * for a REMOTE (function/URL) source the server's results are shown verbatim, in order (no
#     FILTER_CONTAINS re-match / length re-sort), fetched as JSON, with the in-flight request
#     aborted and out-of-order responses dropped (a fetch per keystroke)
#   * addTag/removeTag/tagExist/importTags and the onAddTag/onRemoveTag/onChange callbacks keep
#     working, Enter commits typed text, backspace removes the last tag
describe 'jQuery tagsInput vendored source', :js do
  init_site

  # Synchronous surface: API, init, add/remove, and the array (non-remote, non-debounced) source.
  def sync_probe
    page.evaluate_script(<<~JS)
      (function() {
        var out = {};
        out.api = ['tagsInput', 'addTag', 'removeTag', 'tagExist', 'importTags',
                   'doAutosize', 'resetAutosize'].every(function(m) {
                   return typeof jQuery.fn[m] === 'function'; }) &&
                  typeof jQuery.fn.tagsInput.updateTagsField === 'function' &&
                  typeof jQuery.fn.tagsInput.importTags === 'function';

        var added = [], removed = [];
        var $real = jQuery('<input id="ts_probe" value="alpha,beta">').appendTo('body');
        $real.tagsInput({
          width: '250px',
          onAddTag: function(v) { added.push(v); },
          onRemoveTag: function(v) { removed.push(v); },
          onChange: function() {}
        });
        out.markup = jQuery('#ts_probe_tagsinput').length === 1 &&
                     jQuery('#ts_probe_tagsinput .tag').length === 2;
        out.imported = $real.val() === 'alpha,beta';
        out.hidden = $real.is(':hidden');

        $real.addTag('gamma', { focus: true, callback: true });
        out.add_tag = jQuery('#ts_probe_tagsinput .tag').length === 3 &&
                      $real.val() === 'alpha,beta,gamma' && added.join() === 'gamma';
        $real.addTag('gamma', { focus: false, callback: false, unique: true });
        out.unique = jQuery('#ts_probe_tagsinput .tag').length === 3 &&
                     jQuery('#ts_probe_tag').hasClass('not_valid');
        jQuery('#ts_probe_tag').removeClass('not_valid');

        out.tag_exist = $real.tagExist('beta') === true && $real.tagExist('zzz') === false;
        $real.removeTag(escape('beta'));
        out.remove_tag = $real.val() === 'alpha,gamma' && removed.join() === 'beta';

        jQuery.fn.tagsInput.updateTagsField($real[0], ['x', 'y']);
        out.update_field = $real.val() === 'x,y';

        $real.tagsInput({});
        out.reinit_guard = jQuery('#ts_probe_tagsinput').length === 1;

        // array source: static suggestion list, filtered by the typed text (synchronous)
        var $arr = jQuery('<input id="ts_arr">').appendTo('body');
        $arr.tagsInput({ autocomplete: { source: ['one', 'two'] } });
        var fakeArr = jQuery('#ts_arr_tag')[0];
        fakeArr.value = 'on';
        fakeArr.dispatchEvent(new Event('input'));
        out.array_dropdown = jQuery('#ts_arr_tagsinput .awesomplete ul').children().length === 1;

        // core commit paths: Enter commits, backspace removes the last tag
        var $enter = jQuery('<input id="ts_enter">').appendTo('body');
        $enter.tagsInput({ delimiter: ',' });
        var fakeEnter = jQuery('#ts_enter_tag');
        fakeEnter.val('typed');
        fakeEnter.trigger(jQuery.Event('keypress', { which: 13 }));
        out.enter_commit = $enter.val() === 'typed' && fakeEnter.val() === '';
        fakeEnter.trigger(jQuery.Event('keydown', { keyCode: 8 }));
        out.backspace_removes = $enter.val() === '';

        jQuery('#ts_probe, #ts_probe_tagsinput, #ts_arr, #ts_arr_tagsinput, #ts_enter, #ts_enter_tagsinput').remove();
        jQuery('#ts_arr_tag').each(function() { var a = jQuery(this).data('awesomplete'); if (a) a.destroy(); });
        return out;
      })()
    JS
  end

  # Set up the remote (function + URL) sources and fire their inputs, then read after a wait so an
  # async response has resolved. The jQuery.get stub stays active (stored on window) across the wait.
  def remote_setup
    page.execute_script(<<~JS)
      window.__ts = { fnArg: null, getUrl: null, getParams: null, origGet: jQuery.get };

      var $fn = jQuery('<input id="ts_fn">').appendTo('body');
      $fn.tagsInput({
        autocomplete: {
          // server returns a match that does NOT contain the term, in a fixed order
          source: function(req, resp) { window.__ts.fnArg = req; resp(['nyc-area', 'New York City']); },
          minLength: 2
        }
      });
      var fakeFn = jQuery('#ts_fn_tag')[0];
      fakeFn.value = 'nyc';
      fakeFn.dispatchEvent(new Event('input'));

      jQuery.get = function(url, params) {
        window.__ts.getUrl = url; window.__ts.getParams = params;
        return { done: function(cb) { cb(['gale', 'gamma']); return this; } };
      };
      var $url = jQuery('<input id="ts_url">').appendTo('body');
      $url.tagsInput({ autocomplete_url: '/tag_suggestions' });
      var fakeUrl = jQuery('#ts_url_tag')[0];
      fakeUrl.value = 'ga';
      fakeUrl.dispatchEvent(new Event('input'));
    JS
  end

  def remote_read
    page.evaluate_script(<<~JS)
      (function() {
        var out = {};
        var awFn = jQuery('#ts_fn_tag').data('awesomplete');
        out.min_length_mapped = !!awFn && awFn.minChars === 2;
        out.fn_source_term = !!window.__ts.fnArg && window.__ts.fnArg.term === 'nyc';
        // both server results shown, in server order (FILTER_CONTAINS would drop "New York City")
        out.fn_dropdown = JSON.stringify(Array.prototype.map.call(
          document.querySelectorAll('#ts_fn_tagsinput .awesomplete ul li'),
          function(li) { return li.textContent; })) === '["nyc-area","New York City"]';

        // selecting a suggestion commits it as a tag
        var ev = new CustomEvent('awesomplete-selectcomplete');
        ev.text = { value: 'New York City', label: 'New York City' };
        jQuery('#ts_fn_tag')[0].dispatchEvent(ev);
        out.select_adds = jQuery('#ts_fn').val() === 'New York City' &&
                          jQuery('#ts_fn_tagsinput .tag').length === 1;

        out.url_called = window.__ts.getUrl === '/tag_suggestions';
        out.term_param = !!window.__ts.getParams && window.__ts.getParams.term === 'ga';
        out.url_dropdown = jQuery('#ts_url_tagsinput .awesomplete ul').children().length === 2;

        // restore + cleanup
        jQuery.get = window.__ts.origGet;
        jQuery('#ts_fn_tag, #ts_url_tag').each(function() { var a = jQuery(this).data('awesomplete'); if (a) a.destroy(); });
        jQuery('#ts_fn, #ts_fn_tagsinput, #ts_url, #ts_url_tagsinput').remove();
        return out;
      })()
    JS
  end

  it 'keeps the tagsInput API and the jQuery-UI autocomplete source contract' do
    admin_sign_in
    visit "#{cama_root_relative_path}/admin"
    wait(2)

    sync = sync_probe
    remote_setup
    wait(1) # let the async fetch resolve
    remote = remote_read

    failures = sync.merge(remote).reject { |_check, value| value == true }
    expect(failures).to be_empty,
                        "tagsInput checks that did not pass: #{failures.keys.join(', ')}"
  end
end
