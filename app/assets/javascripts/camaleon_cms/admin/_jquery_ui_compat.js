// jQuery UI sortable compatibility shim (built on SortableJS).
//
// The jQuery 3 upgrade replaced the jQuery UI bundle with SortableJS, which removed
// $.fn.sortable and $.fn.disableSelection from every admin page. Downstream plugins
// still call them unconditionally (cama_contact_form admin_editor.js, post-order
// post_reorder.js, ecommerce admin_product.js...), and a missing method aborts their
// whole ready handler. This shim translates the jQuery UI sortable API those plugins
// use onto SortableJS instances.
//
// Supported options: handle, items, placeholder, delay, disabled, connectWith, and the
// start/update/stop/change/receive/remove callbacks. jQuery UI only options with no
// SortableJS counterpart (axis, cursor, containment, helper, opacity, revert, scroll,
// tolerance...) are accepted and ignored. Supported methods: disable, enable, destroy,
// refresh, option, toArray, serialize, instance, widget.
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

  function translate(options) {
    const sortableOptions = {}

    if (options.handle) sortableOptions.handle = options.handle
    if (options.items) sortableOptions.draggable = options.items
    if (options.placeholder) sortableOptions.ghostClass = options.placeholder
    if (options.delay) sortableOptions.delay = options.delay
    if (options.disabled) sortableOptions.disabled = true
    if (options.connectWith) sortableOptions.group = { name: options.connectWith }

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
    adapt('update', 'onUpdate')
    adapt('stop', 'onEnd')
    adapt('change', 'onChange')
    adapt('receive', 'onAdd')
    adapt('remove', 'onRemove')
    return sortableOptions
  }

  function serialize(instance) {
    // jQuery UI format: item id "prefix-123" -> "prefix[]=123", joined with '&'
    // SortableJS selectors may carry SortableJS's leading '>' (its default for lists) --
    // valid inside SortableJS's own closest() code only, invalid for element.matches().
    const draggable = (instance.options.draggable || '>*').replace(/^>/, '')
    const parts = []
    const children = instance.el.children
    for (let i = 0; i < children.length; i++) {
      const child = children[i]
      if (!child.matches(draggable)) continue
      const match = child.id.match(/^(.+)[-=_](.+)$/)
      if (match) parts.push(match[1] + '[]=' + encodeURIComponent(match[2]))
    }
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
          case 'option':
            if (instance && args.length === 2)
              instance.option(args[0], args[1])
            else if (instance && args.length === 1)
              returnValue = instance.option(args[0])
            else if (args.length === 1 && typeof args[0] === 'object')
              if (instance) for (const key in args[0]) instance.option(key, args[0][key])

            break
          case 'toArray':
            returnValue = instance ? instance.toArray() : []
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
