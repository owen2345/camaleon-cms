# frozen_string_literal: true

require 'rails_helper'

# Regression (PR #1169 review, JQUI-ECOSYSTEM): replacing the jQuery UI bundle with
# SortableJS removed $.fn.sortable and $.fn.disableSelection from every admin page.
# Downstream plugins call them unconditionally (cama_contact_form admin_editor.js is a
# hard gemspec dependency; camaleon-post-order-plugin post_reorder.js; ecommerce
# admin_product.js), and the TypeError aborted their whole ready handler.
# The shim must honor the jQuery UI contract those callers rely on:
#   * .sortable({handle, items, placeholder, update...}) initializes SortableJS instances
#   * callbacks run with the container as `this` and ui.item as a jQuery object
#   * ui.item is the SAME wrapper across start/stop, so post-order's ui.item.startPos
#     written during start is readable during stop
#   * .disableSelection() and the disable/enable/destroy/toArray methods keep working
describe 'jQuery UI sortable compat shim', :js do
  init_site

  def probe_result
    page.evaluate_script(<<~JS)
      (function() {
        var out = {};
        var $list = $('<ul id="shim-probe">' +
          '<li id="probe_a" data-id="a">A</li>' +
          '<li id="probe_b" data-id="b">B</li>' +
          '<li id="probe_c" data-id="c">C</li>' +
          '</ul>').appendTo('body');
        var list = $list[0];
        var seen = {};

        out.has_fn = typeof $.fn.sortable === 'function' && typeof $.fn.disableSelection === 'function';

        // empty collections must not throw (plugins init on dynamic, possibly empty, sets)
        out.empty_ok = $('#does-not-exist').sortable({ handle: '.h' }).length === 0;

        $list.sortable({
          handle: '.drag-handle',
          items: 'li',
          placeholder: 'probe-placeholder',
          axis: 'y',                       // ignored by SortableJS, must be accepted
          cursor: 'move',                  // ignored by SortableJS, must be accepted
          start: function(event, ui) {
            ui.item.startPos = ui.item.index();  // post-order plugin pattern
            seen.start = (this === list) && (ui.item instanceof jQuery) && ui.item.text() === 'A';
          },
          update: function(event, ui) {
            seen.update = (this === list) && $(this).children().length === 3; // ecommerce pattern
          },
          stop: function(event, ui) {
            // startPos set on the start-time wrapper must survive into stop
            seen.stop = (ui.item.startPos === 0) && (typeof ui.item.index() === 'number');
          }
        });

        var instance = window.Sortable.get(list);
        out.instance_created = !!instance;
        out.handle = instance.options.handle === '.drag-handle';
        out.draggable = instance.options.draggable === 'li';
        out.ghost_class = instance.options.ghostClass === 'probe-placeholder';
        out.ignored_ok = true; // axis/cursor accepted without throwing (we got this far)

        // replay the handler chain exactly like a real A-before-B reorder would
        var item = $list.children()[0];
        var evt = function(extra) {
          return $.extend({ item: item, from: list, to: list, oldIndex: 0, newIndex: 1 }, extra);
        };
        instance.options.onStart.call(instance, evt({}));
        instance.options.onUpdate.call(instance, evt({}));
        instance.options.onEnd.call(instance, evt({}));
        out.start_contract = seen.start === true;
        out.update_contract = seen.update === true;
        out.stop_contract = seen.stop === true;

        // re-init replaces the previous instance instead of stacking two on one element
        $list.sortable({ handle: '.drag-handle' });
        out.reinit = (window.Sortable.get(list) !== instance) && !!window.Sortable.get(list);

        // methods
        $list.sortable('disable');
        out.disabled = window.Sortable.get(list).options.disabled === true;
        $list.sortable('enable');
        out.enabled = window.Sortable.get(list).options.disabled === false;
        out.option_get = $list.sortable('option', 'handle') === '.drag-handle';
        out.to_array = JSON.stringify($list.sortable('toArray')) === '["a","b","c"]';
        out.serialize = $list.sortable('serialize') === 'probe[]=a&probe[]=b&probe[]=c';
        out.instance_method = $list.sortable('instance') === window.Sortable.get(list);
        var destroyed = $list.sortable('destroy');
        out.destroyed = (window.Sortable.get(list) == null) && destroyed === $list;

        // disableSelection keeps preventing text selection drags (post-order pattern)
        var $sel = $('<div id="shim-probe-sel">x</div>').appendTo('body');
        $sel.disableSelection();
        var bound = $._data($sel[0], 'events') || {};
        out.disable_selection = !!bound.selectstart || !!bound.mousedown;
        $sel.enableSelection();
        out.enable_selection = $.isEmptyObject($._data($sel[0], 'events') || {});

        $list.remove(); $sel.remove();
        return out;
      })()
    JS
  end

  it 'provides the jQuery UI sortable and disableSelection contracts over SortableJS' do
    admin_sign_in
    visit "#{cama_root_relative_path}/admin"
    wait(2)

    result = probe_result
    failures = result.reject { |_check, value| value == true }
    expect(failures).to be_empty,
                        "compat shim checks that did not pass: #{failures.keys.join(', ')}"
  end
end
