// jQuery UI sortable compatibility shim (built on SortableJS).
//
// The jQuery 3 upgrade replaced the jQuery UI bundle with SortableJS, which removed
// $.fn.sortable and $.fn.disableSelection from every admin page. Downstream plugins
// still call them unconditionally (cama_contact_form admin_editor.js, post-order
// post_reorder.js, ecommerce admin_product.js...), and a missing method aborts their
// whole ready handler. This shim translates the jQuery UI sortable API those plugins
// use onto SortableJS instances.
//
// Supported options: handle, items (a leading combinator like ' > li' is normalized), placeholder,
// delay, disabled, cancel (defaults to form controls, so a drag never starts from an input),
// connectWith (resolved as a selector like jQuery UI, so mutual/one-directional lists connect), and
// the start/update/stop/change/receive/remove callbacks (update maps to onSort so it also fires on a
// cross-list move). jQuery UI only options with no SortableJS counterpart (axis, cursor, containment,
// helper, opacity, revert, scroll, tolerance...) are accepted and ignored. Supported methods: disable,
// enable, destroy, refresh, option (getter, and 2-arg / object-form setters), toArray (element ids,
// like jQuery UI), serialize, instance, widget.
//
// Callbacks follow the jQuery UI contract: `this` is the sortable container element and
// ui.item is the dragged element wrapped in jQuery. The wrapper for a given element is
// cached, so custom properties stored on ui.item during start (e.g. post-order's
// startPos) are still readable in stop, like jQuery UI's persistent currentItem.
//
// Skipped when the host app provides a real jQuery UI, so the shim never clobbers it.
/* global jQuery */

(function($) {
  if (!$ || typeof window.Sortable === 'undefined' || $.fn.sortable || $.fn.disableSelection) return

  // one stable jQuery wrapper per dragged element, like jQuery UI's currentItem
  const wrappers = new WeakMap()

  function wrapItem(item) {
    if (!wrappers.has(item)) wrappers.set(item, $(item))
    return wrappers.get(item)
  }

  // jQuery UI's mouse widget defaults `cancel` to form controls, so a mousedown inside an input
  // never started a drag. SortableJS has no such exclusion, so map it to `filter` and stop that
  // filter from preventing the mousedown (which would kill caret placement / text selection).
  const DEFAULT_CANCEL = 'input,textarea,button,select,option'

  // A jQuery UI items/draggable selector may lead with whitespace and/or a child combinator
  // (' > .x'), which SortableJS keeps but Element.matches() rejects. Normalize to a plain selector.
  function normalizeSelector(selector) {
    return String(selector).replace(/^\s*>?\s*/, '') || '*'
  }

  function matchesSelector(el, selector) {
    try { return el.matches(selector) } catch (e) { return false }
  }

  // Every shim instance shares one group so a connectWith source can reach any target; `put` decides
  // per drop by resolving the SOURCE's connectWith selector against the TARGET element (jQuery UI's
  // connectWith is a selector for the lists its items may drop into). A list with no connectWith
  // accepts nothing from elsewhere -- isolated, like a plain jQuery UI sortable.
  function compatGroup() {
    return {
      name: 'jquery-ui-compat',
      pull: true,
      put: function(to, from) {
        const cw = from.options.connectWith
        return !!cw && matchesSelector(to.el, cw)
      }
    }
  }

  // jQuery UI option name -> SortableJS option(s), for both init translate and runtime `option` sets.
  function translateOptionKey(name, value) {
    switch (name) {
      case 'items': return { draggable: normalizeSelector(value) }
      case 'placeholder': return { ghostClass: value }
      case 'cancel': return { filter: value }
      case 'disabled': return { disabled: !!value }
      default: return { [name]: value } // handle, delay, connectWith pass through by name
    }
  }

  function translate(options) {
    const sortableOptions = { group: compatGroup(), filter: options.cancel || DEFAULT_CANCEL, preventOnFilter: false }

    if (options.handle) sortableOptions.handle = options.handle
    if (options.items) sortableOptions.draggable = normalizeSelector(options.items)
    if (options.placeholder) sortableOptions.ghostClass = options.placeholder
    if (options.delay) sortableOptions.delay = options.delay
    if (options.disabled) sortableOptions.disabled = true
    // kept on the instance so compatGroup().put can read the source's connectWith selector
    if (options.connectWith) sortableOptions.connectWith = options.connectWith

    // jQuery UI: callback(containerElement, event, {item: $dragged, sender: $sourceList})
    function adapt(name, sortableName) {
      if (typeof options[name] !== 'function') return
      sortableOptions[sortableName] = function(evt) {
        return options[name].call(this.el, evt.originalEvent || evt, {
          item: wrapItem(evt.item),
          sender: evt.from ? $(evt.from) : $()
        })
      }
    }

    adapt('start', 'onStart')
    // jQuery UI `update` fires on the list whose order changed AND on both lists for a cross-list
    // move. SortableJS emits `update` only for same-list reorders (add/remove/sort for cross-list),
    // so onSort -- which fires on every changed list including both sides of a cross-list drop -- is
    // the faithful target.
    adapt('update', 'onSort')
    adapt('stop', 'onEnd')
    adapt('change', 'onChange')
    adapt('receive', 'onAdd')
    adapt('remove', 'onRemove')
    return sortableOptions
  }

  // Direct children matching the (normalized) draggable selector, in DOM order.
  function draggableChildren(instance) {
    const selector = normalizeSelector(instance.options.draggable || '>*')
    const out = []
    const children = instance.el.children
    for (let i = 0; i < children.length; i++) {
      if (matchesSelector(children[i], selector)) out.push(children[i])
    }
    return out
  }

  // jQuery UI toArray returns each item's `id` attribute -- NOT SortableJS's data-id / content hash.
  function elementIds(instance) {
    return draggableChildren(instance).map(function(child) { return child.id || '' })
  }

  function serialize(instance) {
    // jQuery UI format: item id "prefix-123" -> "prefix[]=123", joined with '&'
    const parts = []
    draggableChildren(instance).forEach(function(child) {
      const match = child.id.match(/^(.+)[-=_](.+)$/)
      if (match) parts.push(match[1] + '[]=' + encodeURIComponent(match[2]))
    })
    return parts.join('&')
  }

  $.fn.sortable = function(options) {
    const method = typeof options === 'string' ? options : null
    const args = Array.prototype.slice.call(arguments, 1)
    let returnValue = this

    this.each(function() {
      const el = this
      if (method) {
        const instance = window.Sortable.get(el)
        switch (method) {
          case 'disable':
            if (instance) instance.option('disabled', true)
            break
          case 'enable':
            if (instance) instance.option('disabled', false)
            break
          case 'destroy':
            if (instance) instance.destroy()
            break
          case 'refresh':
            break // SortableJS resolves items on the fly, there is nothing to refresh
          case 'option': {
            const applyKV = function(name, value) {
              if (!instance) return
              const mapped = translateOptionKey(name, value)
              for (const k in mapped) instance.option(k, mapped[k])
            }
            if (typeof args[0] === 'object') {
              // jQuery UI multi-option setter: .sortable('option', {disabled: true, handle: '.h'})
              for (const key in args[0]) applyKV(key, args[0][key])
            } else if (args.length >= 2) {
              applyKV(args[0], args[1])
            } else {
              returnValue = instance ? instance.option(args[0]) : undefined
            }
            break
          }
          case 'toArray':
            returnValue = instance ? elementIds(instance) : []
            break
          case 'serialize':
            returnValue = instance ? serialize(instance) : ''
            break
          case 'instance':
            returnValue = instance
            break
          case 'widget':
            returnValue = $(el)
            break
          default:
            if (typeof console !== 'undefined' && console.warn)
              console.warn('jQuery UI compat shim: unsupported sortable method "' + method + '"')
        }
        return
      }

      // a second .sortable() on the same element replaces the previous instance
      const existing = window.Sortable.get(el)
      if (existing) existing.destroy()
      new window.Sortable(el, translate(options || {})) // eslint-disable-line no-new
    })

    return returnValue
  }

  // jQuery UI ui-core equivalents used by e.g. post-order's table dragging
  $.fn.disableSelection = function() {
    const eventType = 'onselectstart' in document.createElement('div') ? 'selectstart' : 'mousedown'
    return this.on(eventType + '.ui-disableSelection', function(event) {
      event.preventDefault()
    })
  }

  $.fn.enableSelection = function() {
    return this.off('.ui-disableSelection')
  }
})(jQuery)
