# frozen_string_literal: true

require 'rails_helper'

# Regression (PR #1169 review, TAGSINPUT/S3/AL3/A1-7): the jQuery 3 rework hand-edited
# the minified xoxco tagsinput bundle, porting the autocomplete branch to Awesomplete
# with a single term-less $.get at init, bare-array responses only and a hardcoded
# minChars. $.fn.tagsInput has no in-repo caller but ships to downstream plugins via
# the admin manifest, so the port must keep the public API and honor the jQuery-UI
# autocomplete source contract the old bundle offered:
#   * source may be an array, a function invoked as source({term}, response) or a URL
#     string fetched with a `term` parameter per keystroke
#   * autocomplete.minLength maps to Awesomplete minChars
#   * addTag/removeTag/tagExist/importTags and the onAddTag/onRemoveTag/onChange
#     callbacks keep working, Enter commits typed text, backspace removes the last tag
describe 'jQuery tagsInput vendored source', :js do
  init_site

  def probe_result
    page.evaluate_script(<<~JS)
      (function() {
        var out = {};

        // public API surface downstream plugins call
        out.api = ['tagsInput', 'addTag', 'removeTag', 'tagExist', 'importTags',
                   'doAutosize', 'resetAutosize'].every(function(m) {
                   return typeof jQuery.fn[m] === 'function'; }) &&
                  typeof jQuery.fn.tagsInput.updateTagsField === 'function' &&
                  typeof jQuery.fn.tagsInput.importTags === 'function';

        // init: markup built after the input, initial value imported, real input hidden
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

        // addTag round-trip + unique duplicates rejection
        $real.addTag('gamma', { focus: true, callback: true });
        out.add_tag = jQuery('#ts_probe_tagsinput .tag').length === 3 &&
                      $real.val() === 'alpha,beta,gamma' && added.join() === 'gamma';
        $real.addTag('gamma', { focus: false, callback: false, unique: true });
        out.unique = jQuery('#ts_probe_tagsinput .tag').length === 3 &&
                     jQuery('#ts_probe_tag').hasClass('not_valid');
        jQuery('#ts_probe_tag').removeClass('not_valid');

        out.tag_exist = $real.tagExist('beta') === true && $real.tagExist('zzz') === false;

        // removeTag (callers pass the escaped value, like the tag x click does)
        $real.removeTag(escape('beta'));
        out.remove_tag = $real.val() === 'alpha,gamma' && removed.join() === 'beta';

        jQuery.fn.tagsInput.updateTagsField($real[0], ['x', 'y']);
        out.update_field = $real.val() === 'x,y';

        // re-init guard: a second tagsInput() call must not duplicate the widget
        $real.tagsInput({});
        out.reinit_guard = jQuery('#ts_probe_tagsinput').length === 1;

        // function source: jQuery-UI contract source({term}, response) + minLength mapping
        var fnArg = null;
        var $fn = jQuery('<input id="ts_fn">').appendTo('body');
        $fn.tagsInput({
          autocomplete: {
            source: function(req, resp) { fnArg = req; resp(['alpha', 'alpine']); },
            minLength: 2
          }
        });
        var fakeFn = jQuery('#ts_fn_tag')[0];
        fakeFn.value = 'al';
        fakeFn.dispatchEvent(new Event('input'));
        var awFn = jQuery('#ts_fn_tag').data('awesomplete');
        out.fn_source_term = !!fnArg && fnArg.term === 'al';
        out.min_length_mapped = !!awFn && awFn.minChars === 2;
        out.fn_dropdown = jQuery('#ts_fn_tagsinput .awesomplete ul').children().length === 2;

        // selecting a suggestion commits it as a tag
        var ev = new CustomEvent('awesomplete-selectcomplete');
        ev.text = { value: 'alpine', label: 'alpine' };
        fakeFn.dispatchEvent(ev);
        out.select_adds = $fn.val() === 'alpine' &&
                          jQuery('#ts_fn_tagsinput .tag').length === 1;

        // string source (autocomplete_url): fetched per keystroke WITH a term parameter
        var getUrl = null, getParams = null;
        var origGet = jQuery.get;
        jQuery.get = function(url, params) {
          getUrl = url; getParams = params;
          return { done: function(cb) { cb(['gale', 'gamma']); return this; } };
        };
        var $url = jQuery('<input id="ts_url">').appendTo('body');
        $url.tagsInput({ autocomplete_url: '/tag_suggestions' });
        var fakeUrl = jQuery('#ts_url_tag')[0];
        fakeUrl.value = 'ga';
        fakeUrl.dispatchEvent(new Event('input'));
        jQuery.get = origGet;
        out.url_called = getUrl === '/tag_suggestions';
        out.term_param = !!getParams && getParams.term === 'ga';
        out.url_dropdown = jQuery('#ts_url_tagsinput .awesomplete ul').children().length === 2;

        // array source: static suggestion list, filtered by the typed text
        var $arr = jQuery('<input id="ts_arr">').appendTo('body');
        $arr.tagsInput({ autocomplete: { source: ['one', 'two'] } });
        var fakeArr = jQuery('#ts_arr_tag')[0];
        fakeArr.value = 'on';
        fakeArr.dispatchEvent(new Event('input'));
        out.array_dropdown = jQuery('#ts_arr_tagsinput .awesomplete ul').children().length === 1;

        // core commit paths stay intact: Enter commits, backspace removes the last tag
        var $enter = jQuery('<input id="ts_enter">').appendTo('body');
        $enter.tagsInput({ delimiter: ',' });
        var fakeEnter = jQuery('#ts_enter_tag');
        fakeEnter.val('typed');
        fakeEnter.trigger(jQuery.Event('keypress', { which: 13 }));
        out.enter_commit = $enter.val() === 'typed' && fakeEnter.val() === '';
        fakeEnter.trigger(jQuery.Event('keydown', { keyCode: 8 }));
        out.backspace_removes = $enter.val() === '';

        // cleanup: destroy autocomplete instances, then drop the probe markup
        jQuery('#ts_fn_tag, #ts_url_tag, #ts_arr_tag').each(function() {
          var a = jQuery(this).data('awesomplete');
          if (a) { a.destroy(); }
        });
        jQuery('#ts_probe, #ts_probe_tagsinput, #ts_fn, #ts_fn_tagsinput, #ts_url, #ts_url_tagsinput, #ts_arr, #ts_arr_tagsinput, #ts_enter, #ts_enter_tagsinput').remove();
        jQuery('tester[id$="_autosize_tester"]').remove();

        return out;
      })()
    JS
  end

  it 'keeps the tagsInput API and the jQuery-UI autocomplete source contract' do
    admin_sign_in
    visit "#{cama_root_relative_path}/admin"
    wait(2)

    result = probe_result
    failures = result.reject { |_check, value| value == true }
    expect(failures).to be_empty,
                        "tagsInput checks that did not pass: #{failures.keys.join(', ')}"
  end
end
