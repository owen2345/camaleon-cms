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
        instance.options.onSort.call(instance, evt({})); // jQuery UI `update` maps to onSort
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
        // jQuery UI toArray returns element ids, not SortableJS's data-id/hash
        out.to_array = JSON.stringify($list.sortable('toArray')) === '["probe_a","probe_b","probe_c"]';
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

  # PR #1169 review finding #10 -- contract points the first probe missed: form-control cancel,
  # leading-combinator items, the object-form option setter, and connectWith selector resolution.
  def contract_result
    page.evaluate_script(<<~JS)
      (function() {
        var out = {};
        var $list = $('<ul id="c-list"><li id="post_1">1</li><li id="post_2">2</li></ul>').appendTo('body');

        // cancel defaults to form controls, mapped to a non-preventing filter
        $list.sortable({ update: function(){} });
        var inst = window.Sortable.get($list[0]);
        out.filter_excludes_inputs = typeof inst.options.filter === 'string' && inst.options.filter.indexOf('input') !== -1;
        out.filter_non_preventing = inst.options.preventOnFilter === false;
        out.update_maps_to_onsort = typeof inst.options.onSort === 'function';
        $list.sortable('destroy');

        // a leading child-combinator in items must not break draggable/toArray/serialize
        $list.sortable({ items: ' > li' });
        out.items_leading_combinator = JSON.stringify($list.sortable('toArray')) === '["post_1","post_2"]';
        var ok = true; try { $list.sortable('serialize'); } catch (e) { ok = false; }
        out.serialize_no_throw = ok;
        $list.sortable('destroy');

        // object-form option setter actually applies
        $list.sortable({ handle: '.h' });
        $list.sortable('option', { disabled: true });
        out.option_object_form = window.Sortable.get($list[0]).options.disabled === true;
        $list.sortable('destroy');

        // connectWith: mutual selectors connect (put resolves the source's selector); a list with no
        // connectWith rejects foreign items
        var $a = $('<ul id="cw_a"><li>a</li></ul>').appendTo('body');
        var $b = $('<ul id="cw_b"><li>b</li></ul>').appendTo('body');
        var $c = $('<ul id="cw_c"><li>c</li></ul>').appendTo('body');
        $a.sortable({ connectWith: '#cw_b' });
        $b.sortable({ connectWith: '#cw_a' });
        $c.sortable({});
        var ia = window.Sortable.get($a[0]), ib = window.Sortable.get($b[0]), ic = window.Sortable.get($c[0]);
        out.connect_same_group = ia.options.group.name === ib.options.group.name;
        out.b_accepts_a = ib.options.group.checkPut(ib, ia, null, null) === true;
        out.plain_rejects_a = ic.options.group.checkPut(ic, ia, null, null) === false;

        $list.remove(); $a.remove(); $b.remove(); $c.remove();
        return out;
      })()
    JS
  end

  it 'honors cancel, leading-combinator items, the object option setter, and connectWith' do
    admin_sign_in
    visit "#{cama_root_relative_path}/admin"
    wait(2)

    result = contract_result
    failures = result.reject { |_check, value| value == true }
    expect(failures).to be_empty,
                        "compat shim contract checks that did not pass: #{failures.keys.join(', ')}"
  end
end
