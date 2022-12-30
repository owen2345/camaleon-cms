/* eslint-env jquery */
/* eslint-disable-next-line no-unused-vars */
function log(d) {
  if (console.log)
    console.log(d)
}

// prepend flash message into current element
// message: text message
// kind: string kind of message, default danger (success, danger, info, warning)
// sample: $("my_ele").flash_message("updated", "success");
jQuery(function() {
  $.fn.flash_message = function(message, kind) {
    if (!kind) kind = !message ? 'success' : 'danger'
    if (!message) message = I18n('msg.success_action', 'Action completed successfully.')
    const msg = '<div class="alert alert-' + kind + '"> <button type="button" class="close" data-dismiss="alert" aria-label="Close"><span aria-hidden="true">&times;</span></button> ' + message + ' </div>'
    $(this).prepend(msg)
    return this
  }
})

/** **************** form validations ************/
// panel can be a object: $("#my_form")
// if panel is null, then this will be replaced by body
// args: {validate_settings}
/* eslint-disable-next-line no-unused-vars */
const InitFormValidations = function(form, args) {
  args = args || {};
  // slug management
  // you need to add class no_translate to avoid translations in slugs
  (form || $('#admin_content')).find('input.slug').each(function() {
    const slId = $(this).attr('data-parent')
    if (!slId) return
    const $parent = $('#' + slId)
    if ($parent.hasClass('translated-item')) {
      const $panelParent = $parent.siblings('.trans_panel:first')
      if ($(this).hasClass('no_translate'))
        $(this).slugify('#' + $panelParent.find('.tab-content .tab-pane:first input:first').attr('id'))
      else {
        $(this).addClass('translatable').Translatable(ADMIN_TRANSLATIONS)
        const $panelSlug = $(this).siblings('.trans_panel:first')
        $panelParent.find('.tab-content .tab-pane').each(function(index, tabPane) {
          const pId = $(tabPane).children('input').attr('id')
          $panelSlug.find('.tab-content .tab-pane:eq(' + index + ') input:first').slugify('#' + pId)
        })
        $panelParent.find('.nav > li a').each(function(index, aTab) {
          $(aTab).click(function() {
            $panelSlug.find('.nav > li:eq(' + index + ') a').click()
          })
        })
      }
    } else
      $(this).slugify('#' + slId)
  });

  (form || $('#admin_content form')).each(function() {
    const $form = $(this)
    if ($form.find('.translatable').length > 0)
      $form.find('.translatable').Translatable()
  }).filter('.validate').each(function() {
    $(this).validate(args.validate_settings)
  })
};

// file uploader
(function($) {
  // sample: <input name="icon" class="upload_input" type="hidden" data-dimension="23x22" value="current_image_url"/>
  //          $(".upload_input").input_upload({label: '', title: 'Select Images', type: 'image', dimension: '30x30'});
  $.fn.input_upload = function(optionsInit) {
    let defaultOptions = { label: I18n('msg.upload_image'), type: 'image', ext: 'none', icon: 'upload', full_url: true, height: '100px' }
    defaultOptions = $.extend({}, defaultOptions, optionsInit || {})
    $(this).each(function() {
      const $that = $(this)
      const options = $.extend({}, defaultOptions, $that.data() || {})
      const $contentImage = $("<div class='content-upload-plugin'><a style='' href='#' target='_blank'><img src=''><br><span class='rm-file btn btn-xs btn-danger'><i class='fa fa-trash'></i></span></a></div>").hide()
      if (options.type !== 'image') $contentImage.find('img').remove()
      const $btnUpload = $('<a class="btn btn-default" href="#"><i class="fa fa-upload"></i> ' + options.label + '</a>')
      $contentImage.find('img').css('max-height', options.height)
      $contentImage.find('.rm-file').click(function() { $that.val('').trigger('change'); return false })

      $btnUpload.click(function() {
        $.fn.upload_filemanager({
          formats: options.type,
          selected: function(file, response) {
            $that.val(file.url).trigger('change')
          },
          dimension: $that.attr('data-dimension') || options.dimension,
          versions: $that.attr('data-versions') || options.versions,
          thumb_size: $that.attr('data-thumb_size') || options.thumb_size,
          title: $that.attr('title') || options.title
        })
        return false
      })

      $that.after($contentImage).after($btnUpload)
      $that.change(function() {
        const url = $that.val()
        if (url) {
          $contentImage.find('img').attr('src', url)
          $contentImage.find('a').attr('href', url)
          // $contentImage.find('strong').html(_.last(url.split('/')));
          $contentImage.show()
        } else
          $contentImage.hide()
      }).trigger('change')
    })
  }

  // create inline input file uploader with an icon to upload file
  // options: all options needed for uploader
  // you can add an attribute "data-format" in the input to define the file formats required
  $.fn.input_upload_field = function(options) {
    this.each(function() {
      const input = $(this)
      const def = {
        formats: (input.attr('data-format') || 'image'),
        selected: function(file) {
          input.val(file.url)
        }
      }
      if (!input.parent().hasClass('input-group')) {
        input.wrap('<div class="group-input-fields-content input-group"></div>')
        input.after('<span class="input-group-addon btn_upload"><i class="fa fa-upload"></i> </span>')
        input.addClass('form-control')
      }
      input.next('span').click(function() {
        $.fn.upload_filemanager($.extend({}, def, (options || {})))
      })
    })
  }
})(jQuery)

// serialize form into json
// eslint-disable-next-line no-unused-expressions
!(function($) {
  jQuery.fn.serializeObject = function() {
    const json = {}
    jQuery.map(
      jQuery(this).serializeArray(), function(n, i) {
        const __i = n.name.indexOf('[')
        if (__i > -1) {
          let o = json
          const _name = n.name.replace(/\]/gi, '').split('[')
          for (let idx = 0, len = _name.length; idx < len; idx++) {
            const currentName = _name[idx]
            if (idx === len - 1) {
              if (o[currentName] && $.trim(currentName) === '') {
                if (typeof o[currentName] === 'string')
                  o[currentName] = [o[currentName]]
                o[currentName].push(n.value)
              } else
                o[currentName] = n.value || ''
            } else
              o = o[currentName] = o[currentName] || {}
          }
        } else if (json[n.name] !== undefined) {
          if (!json[n.name].push) json[n.name] = [json[n.name]]; json[n.name].push(n.value || '')
        } else
          json[n.name] = n.value || ''
      }
    )
    return json
  }
})(jQuery)

// jquery browser support
// eslint-disable-next-line no-unused-expressions, no-void, no-sequences, no-useless-escape, no-mixed-operators, no-return-assign
!(function(a) { typeof define === 'function' && define.amd ? define(['jquery'], function(b) { a(b) }) : typeof module === 'object' && typeof module.exports === 'object' ? module.exports = a(require('jquery')) : a(window.jQuery) }(function(a) { 'use strict'; function b(a) { void 0 === a && (a = window.navigator.userAgent), a = a.toLowerCase(); const b = /(edge)\/([\w.]+)/.exec(a) || /(opr)[\/]([\w.]+)/.exec(a) || /(chrome)[ \/]([\w.]+)/.exec(a) || /(version)(applewebkit)[ \/]([\w.]+).*(safari)[ \/]([\w.]+)/.exec(a) || /(webkit)[ \/]([\w.]+).*(version)[ \/]([\w.]+).*(safari)[ \/]([\w.]+)/.exec(a) || /(webkit)[ \/]([\w.]+)/.exec(a) || /(opera)(?:.*version|)[ \/]([\w.]+)/.exec(a) || /(msie) ([\w.]+)/.exec(a) || a.indexOf('trident') >= 0 && /(rv)(?::| )([\w.]+)/.exec(a) || a.indexOf('compatible') < 0 && /(mozilla)(?:.*? rv:([\w.]+)|)/.exec(a) || []; const c = /(ipad)/.exec(a) || /(ipod)/.exec(a) || /(iphone)/.exec(a) || /(kindle)/.exec(a) || /(silk)/.exec(a) || /(android)/.exec(a) || /(windows phone)/.exec(a) || /(win)/.exec(a) || /(mac)/.exec(a) || /(linux)/.exec(a) || /(cros)/.exec(a) || /(playbook)/.exec(a) || /(bb)/.exec(a) || /(blackberry)/.exec(a) || []; const d = {}; const e = { browser: b[5] || b[3] || b[1] || '', version: b[2] || b[4] || '0', versionNumber: b[4] || b[2] || '0', platform: c[0] || '' }; if (e.browser && (d[e.browser] = !0, d.version = e.version, d.versionNumber = parseInt(e.versionNumber, 10)), e.platform && (d[e.platform] = !0), (d.android || d.bb || d.blackberry || d.ipad || d.iphone || d.ipod || d.kindle || d.playbook || d.silk || d['windows phone']) && (d.mobile = !0), (d.cros || d.mac || d.linux || d.win) && (d.desktop = !0), (d.chrome || d.opr || d.safari) && (d.webkit = !0), d.rv || d.edge) { const f = 'msie'; e.browser = f, d[f] = !0 } if (d.safari && d.blackberry) { const g = 'blackberry'; e.browser = g, d[g] = !0 } if (d.safari && d.playbook) { const h = 'playbook'; e.browser = h, d[h] = !0 } if (d.bb) { const i = 'blackberry'; e.browser = i, d[i] = !0 } if (d.opr) { const j = 'opera'; e.browser = j, d[j] = !0 } if (d.safari && d.android) { const k = 'android'; e.browser = k, d[k] = !0 } if (d.safari && d.kindle) { const l = 'kindle'; e.browser = l, d[l] = !0 } if (d.safari && d.silk) { const m = 'silk'; e.browser = m, d[m] = !0 } return d.name = e.browser, d.platform = e.platform, d } return window.jQBrowser = b(window.navigator.userAgent), window.jQBrowser.uaMatch = b, a && (a.browser = window.jQBrowser), window.jQBrowser }))
