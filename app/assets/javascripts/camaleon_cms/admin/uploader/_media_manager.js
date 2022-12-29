/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/main/docs/suggestions.md
 */

/* eslint-env jquery */
window.cama_init_media = function(mediaPanel) {
  const mediaInfo = mediaPanel.find('.media_file_info')
  const mediaFilesPanel = mediaPanel.find('.media_browser_list')
  const mediaInfoTabInfo = mediaPanel.find('.media_file_info_col .nav-tabs .link_media_info')
  const mediaLinkTabUpload = mediaPanel.find('.media_file_info_col .nav-tabs .link_media_upload')

  // ############### visualize item
  // loading last opened folder on current page
  mediaPanel.ready(function() {
    const f = $('body').data('last-folder')
    return mediaPanel.trigger('navigate_to', { folder: f })
  })

  // return the data of this file
  const fileData = function(item) {
    const data = item.data('eval-data') || eval('(' + item.find('.data_value').val() + ')')
    item.data('eval-data', data)
    return data
  }

  const showFile = function(item) {
    item.addClass('selected').siblings().removeClass('selected')
    const data = fileData(item)
    mediaInfoTabInfo.click()
    let tpl =
      "<div class='p_thumb'></div>" +
        "<div class='p_label'><b>" + I18n('button.name') + ': </b><br> <span>' + data.name + '</span></div>' +
        "<div class='p_body'>" +
        "<div style='overflow: auto'><b>" +
        I18n('button.url') + ":</b><br> <a target='_blank' href='" + data.url + "'>" + data.url + '</a></div>' +
        '<div><b>' + I18n('button.size') + ':</b> <span>' +
        window.camaHumanFileSize(parseFloat(data.file_size)) + '</span></div>' +
        '</div>'

    if (window.callback_media_uploader) {
      if (
        !mediaPanel.attr('data-formats') ||
          (mediaPanel.attr('data-formats') &&
            (
              ($.inArray(data.file_type, mediaPanel.attr('data-formats').split(',')) >= 0) ||
                ($.inArray(data.url.split('.').pop().toLowerCase(), mediaPanel.attr('data-formats').split(',')) >= 0))
          )
      ) {
        tpl += "<div class='p_footer'>" +
          "<button class='btn btn-primary insert_btn'>" + I18n('button.insert') + '</button>' +
          '</div>'
      }
    }

    mediaInfo.html(tpl)
    mediaInfo.find('.p_thumb').html(item.find('.thumb').html())
    if (data.file_type === 'image') {
      let editImg

      if (item.find('.edit_item')) { // add button to edit image
        editImg = $(
          '<button type="button" class="pull-right btn btn-default" title="Edit"><i class="fa fa-pencil"></i></button>').click(() => item.find('.edit_item').trigger('click')
        )
      }
      mediaInfo.find('.p_footer').append(editImg)
      const drawImage = function() {
        const ww = parseInt(data.dimension.split('x')[0])
        const hh = parseInt(data.dimension.split('x')[1])
        mediaInfo.find('.p_body').append(
          "<div class='cdimension'><b>" + I18n('button.dimension') + ': </b><span>' + ww + 'x' + hh + '</span></div>'
        )

        if (mediaPanel.attr('data-dimension')) { // verify dimensions
          const btn = mediaInfo.find('.p_footer .insert_btn')
          btn.prop('disabled', true)
          const _ww = parseInt(mediaPanel.attr('data-dimension').split('x')[0]) || ww
          const _hh = parseInt(mediaPanel.attr('data-dimension').split('x')[1]) || hh
          mediaInfo.find('.cdimension')
            .append("<span style='color: black'> ==> " + mediaPanel.attr('data-dimension') + '</span>')

          if ((_ww === ww) && (_hh === hh))
            return btn.prop('disabled', false)
          else {
            mediaInfo.find('.cdimension').css('color', 'red')
            const cut = $("<button class='btn btn-info pull-right'><i class='fa fa-crop'></i> " +
                          I18n('button.auto_crop') + '</button>').click(function() {
              const cropName = data.name.split('.')
              cropName[cropName.length - 2] += '_' + mediaPanel.attr('data-dimension')
              return $.fn.upload_url({ url: data.url, name: cropName.join('.') })
            })
            return btn.after(cut)
          }
        }
      }

      // if not dimension in the image and required dimension
      if (!data.dimension && mediaPanel.attr('data-dimension')) {
        const img = new Image()
        img.onload = function() {
          data.dimension = this.width + 'x' + this.height
          item.data('eval-data', data)
          return drawImage()
        }
        img.src = data.url
      } else
        drawImage()
    }

    if (window.callback_media_uploader) { // trigger callback
      return mediaInfo.find('.insert_btn').click(function() {
        data.mime = data.type
        window.callback_media_uploader(data)
        window.callback_media_uploader = null
        mediaPanel.closest('.modal').modal('hide')
        return false
      })
    }
  }

  mediaPanel.on('click', '.file_item', function() {
    showFile($(this))
    return false
  }).on('dblclick', '.file_item', function() { // # auto select on double click
    const btn = mediaInfo.find('.insert_btn')
    if (btn && !btn.attr('disabled') && !btn.attr('readonly'))
      return btn.trigger('click')
  })

  mediaFilesPanel.scroll(function() {
    if (mediaFilesPanel.attr('data-next-page') &&
      (($(this).scrollTop() + $(this).outerHeight()) === $(this)[0].scrollHeight)) {
      return mediaPanel.trigger(
        'navigate_to', { paginate: true, custom_params: { page: mediaFilesPanel.attr('data-next-page') } }
      )
    }
  })
  // end visualize item

  // ######### file uploader
  const pUpload = mediaPanel.find('.cama_media_fileuploader')
  const customFileData = function() {
    const r = window.cama_media_get_custom_params()
    r.skip_auto_crop = true
    return r
  }

  pUpload.uploadFile({
    url: pUpload.attr('data-url'),
    fileName: 'file_upload',
    sequential: true,
    sequentialCount: 1,
    uploadButtonClass: 'btn btn-primary btn-block',
    dragDropStr: '<span style="display: block"><b>' + pUpload.attr('data-dragDropStr') + '</b></span>',
    uploadStr: pUpload.attr('data-uploadStr'),
    dynamicFormData: customFileData,
    onSuccess(files, resUpload, xhr, pd) {
      if (resUpload.search('media_item') >= 0) { // success upload
        mediaPanel.trigger(
          'add_file', { item: resUpload, selected: $(pd.statusbar).siblings().not('.error_file_upload').length === 0 }
        )
        return $(pd.statusbar).remove()
      } else {
        return $(pd.statusbar)
          .find('.ajax-file-upload-progress').html("<span style='color: red'>" + resUpload + '</span>')
      }
    },
    onError(files, status, errMsg, pd) {
      return $(pd.statusbar)
        .addClass('error_file_upload')
        .find('.ajax-file-upload-filename')
        .append(
          " <i class='fa fa-times btn btn-danger btn-xs' onclick='$(this).closest(\".ajax-file-upload-statusbar\").remove()'></i>"
        )
    }
  })
  // # end file uploader

  // ######## folders breadcrumb
  mediaPanel.find('.media_folder_breadcrumb').on('click', 'a', function() {
    mediaPanel.trigger('navigate_to', { folder: $(this).attr('data-path') })
    return false
  })
  mediaPanel.on('click', '.folder_item', function() {
    let f = mediaPanel.attr('data-folder') + '/' + $(this).attr('data-key')
    if ($(this).attr('data-key').search('/') >= 0)
      f = $(this).attr('data-key')

    f = f.replace(/\/{2,}/g, '/')
    mediaPanel.trigger('navigate_to', { folder: f })
    return $('body').attr('data-last-folder', f) // remembers last opened folder on current page
  })
  mediaPanel.bind('update_breadcrumb', function() {
    let folderItems
    const folder = mediaPanel.attr('data-folder').replace('//', '/')
    const folderPrefix = []
    if ((folder === '/') || (folder === ''))
      folderItems = ['/']
    else
      folderItems = folder.split('/')

    const breadrumb = []
    for (let index = 0; index < folderItems.length; index++) {
      const value = folderItems[index]
      let name = value
      if ((value === '/') || (value === ''))
        name = I18n('button.root')

      if (index === (folderItems.length - 1))
        breadrumb.push('<li><span>' + name + '</span></li>')
      else {
        folderPrefix.push(value)
        breadrumb.push(
          "<li><a data-path='" + (folderPrefix.join('/') || '/').replace(/\/{2,}/g, '/') + "' href='#'>" + name + '</a></li>'
        )
      }
    }
    return mediaPanel.find('.media_folder_breadcrumb').html(breadrumb.join(''))
  }).trigger('update_breadcrumb')
  // # end folders

  // ######## folder navigation
  mediaPanel.bind('navigate_to', function(e, data) {
    if (data.folder)
      mediaPanel.attr('data-folder', data.folder)

    const folder = mediaPanel.attr('data-folder')
    mediaPanel.trigger('update_breadcrumb')
    let reqParams = window.cama_media_get_custom_params({ partial: true, folder })
    if (data.paginate)
      reqParams = mediaPanel.data('last_req_params') || reqParams
    else {
      mediaInfo.html('')
      mediaLinkTabUpload.click()
    }

    mediaPanel.data('last_req_params', $.extend({}, reqParams, data.custom_params || {}))
    showLoading()

    return $.getJSON(mediaPanel.attr('data-url'), mediaPanel.data('last_req_params'), function(res) {
      if (data.paginate) {
        if (mediaFilesPanel.children('.file_item').length > 0)
          mediaFilesPanel.append(res.html)
        else {
          const lastFolder = mediaFilesPanel.children('.folder_item:last')
          if (lastFolder.length === 1)
            lastFolder.after(res.html)
          else
            mediaFilesPanel.append(res.html)
        }
      } else
        mediaFilesPanel.html(res.html)

      mediaFilesPanel.attr('data-next-page', res.next_page)
      return hideLoading()
    })
  }).bind('add_file', function(e, data) {
    // add html item in the list
    const item = $(data.item).hide()
    const lastFolder = mediaFilesPanel.children('.folder_item:last')

    if (lastFolder.length === 1)
      lastFolder.after(item)
    else
      mediaFilesPanel.prepend(item)

    if ((data.selected === true) || (data.selected === undefined))
      item.click()

    mediaFilesPanel.scrollTop(0)
    return item.fadeIn(1500)
  })

  // search file
  mediaPanel.find('#cama_search_form').submit(function() {
    mediaPanel.trigger('navigate_to', { custom_params: { search: $(this).find('input:text').val() } })
    return false
  })

  // reload current directory
  mediaPanel.find('.cam_media_reload').click(function(e, data) {
    mediaPanel.trigger('navigate_to', { custom_params: { cama_media_reload: $(this).attr('data-action') } })
    return e.preventDefault()
  })

  // element actions
  mediaPanel.on('click', 'a.add_folder', function() {
    const content = $(
      "<form id='add_folder_form'><div><label for=''>" + I18n('button.folder') +
        ": </label> <div class='input-group'><input name='folder' class='form-control required' placeholder='Folder name..'><span class='input-group-btn'><button class='btn btn-primary' type='submit'>" +
        I18n('button.create') +
        '</button></span></div></div> </form>'
    )
    const callback = function(modal) {
      const btn = modal.find('.btn-primary')
      const input = modal.find('input').keyup(function() {
        if ($(this).val())
          return btn.removeAttr('disabled')
        else
          return btn.attr('disabled', 'true')
      }).trigger('keyup')
      return modal.find('form').submit(function() {
        showLoading()
        $.post(
          mediaPanel.attr('data-url_actions'),
          window.cama_media_get_custom_params(
            { folder: mediaPanel.attr('data-folder') + '/' + input.val(), media_action: 'new_folder' }
          ),
          function(res) {
            hideLoading()
            modal.modal('hide')
            if (res.search('folder_item') >= 0) {
              // success upload
              res = $(res)
              mediaFilesPanel.append(res)
              return res.click()
            } else
              return $.fn.alert({ type: 'error', content: res, title: 'Error' })
          })
        return false
      })
    }
    open_modal({ title: 'New Folder', content, callback, zindex: 9999999 })
    return false
  })

  // destroy file and folder
  mediaPanel.on('click', 'a.del_item, a.del_folder', function() {
    if (!confirm(I18n('msg.delete_item')))
      return false

    const link = $(this)
    const item = link.closest('.media_item')
    showLoading()
    $.post(
      mediaPanel.attr('data-url_actions'),
      window.cama_media_get_custom_params(
        {
          folder: mediaPanel.attr('data-folder') + '/' + item.attr('data-key'),
          media_action: link.hasClass('del_folder') ? 'del_folder' : 'del_file'
        }
      ),
      function(res) {
        hideLoading()
        if (res)
          return $.fn.alert({ type: 'error', content: res, title: I18n('button.error') })
        else {
          item.remove()
          return mediaInfo.html('')
        }
      }
    ).error(() => $.fn.alert({ type: 'error', content: I18n('msg.internal_error'), title: I18n('button.error') }))
    return false
  })

  // edit image
  mediaPanel.on('click', '.edit_item', function() {
    const link = $(this)
    const item = link.closest('.media_item')
    const data = fileData(item)
    let cropper = null
    let cropperData = null

    const editCallback = function(modal) {
      const fieldWidth = modal.find('.export_image .with_image')
      const fieldHeight = modal.find('.export_image .height_image')
      const saveImage = (name, sameName) => $.fn.upload_url({
        url: cropper.cropper('getCroppedCanvas', { width: fieldWidth.val(), height: fieldHeight.val() }).toDataURL('image/jpeg'),
        name,
        sameName,
        callback(res) {
          return modal.modal('hide')
        }
      })

      // add buttons
      const object = {
        arrows: "('setDragMode', 'move')",
        crop: "('setDragMode', 'crop')",
        'search-plus': "('zoom', 0.1)",
        'search-minus': "('zoom', -0.1)",
        'arrow-left': "('move', -10, 0)",
        'arrow-right': "('move', 10, 0)",
        'arrow-up': "('move', 0, -10)",
        'arrow-down': "('move', 0, 10)",
        'rotate-left': "('rotate', -45)",
        'rotate-right': "('rotate', 45)",
        'arrows-h': "('scaleX', -1)",
        'arrows-v': "('scaleY', -1)",
        refresh: "('reset')"
      }

      for (const icon in object) {
        let cmd = object[icon]
        let btn = $(
          '<button type="button" class="btn btn-default" data-cmd="' + cmd + '"><i class="fa fa-' + icon + '"></i></button>'
        )

        modal.find('.editor_controls').append(btn)
        btn.click(function() {
          btn = $(this)
          cmd = btn.data('cmd')
          if ((cmd === "('scaleY', -1)") || (cmd === "('scaleX', -1)"))
            btn.data('cmd', cmd.replace('-1', '1'))
          else if ((cmd === "('scaleY', 1)") || (cmd === "('scaleX', 1)"))
            btn.data('cmd', cmd.replace('1', '-1'))

          eval('cropper.cropper' + cmd)
          if (cmd === "('reset')")
            return cropper.cropper('setData', cropperData.data)
        })
      }

      // save edited image
      const save_btn = modal.find('.export_image').submit(function() {
        if (!$(this).valid())
          return false

        const saveButtons = function(modal2) {
          modal2.find('img.preview').attr('src', cropper.cropper('getCroppedCanvas', { width: fieldWidth.val(), height: fieldHeight.val() }).toDataURL('image/jpeg'))
          modal2.find('.save_btn').click(function() {
            saveImage(data.name, true)
            modal2.modal('hide')
            return item.remove()
          })
          return modal2.find('form').validate({
            submitHandler() {
              saveImage(modal2.find('.file_name').val() + '.' + data.name.split('.').pop())
              modal2.modal('hide')
              return false
            }
          })
        }
        open_modal(
          {
            zindex: 999992,
            modal_size: 'modal-lg',
            id: 'media_preview_editted_image',
            content: '<div class="text-center" style="overflow: auto"><img class="preview"></div><br><div class="row"><div class="col-md-4"><button class="btn save_btn btn-default">' + I18n('button.replace_image') + '</button></div><div class="col-md-8"><form class="input-group"><input type="text" class="form-control file_name required" name="file_name"><div class="input-group-btn"><button class="btn btn-primary" type="submit">' + I18n('button.save_new_image') + '</button></div></form></div></div>',
            callback: saveButtons
          }
        )
        return false
      }).validate()

      // custom sizes auto calculate aspect ratio
      fieldWidth.change(function() {
        if (!fieldWidth.attr('readonly')) {
          const croperArea = modal.find('.cropper-crop-box')
          return fieldHeight.val(parseInt((parseInt($(this).val()) / croperArea.width()) * croperArea.height()))
        }
      })

      // show cropper image
      showLoading()
      return modal.find('img.editable').load(() => setTimeout(function() {
        const label = modal.find('.label_dimension')
        cropperData = {
          data: {},
          minContainerHeight: 450,
          modal: true,
          crop(e) {
            label.html(Math.round(e.width) + ' x ' + Math.round(e.height))
            if (!fieldWidth.attr('readonly'))
              fieldWidth.val(Math.round(e.width))

            if (!fieldHeight.attr('readonly'))
              return fieldHeight.val(Math.round(e.height))
          },
          built() {
            return $.get(data.url)
              .error(
                () => modal.find('.modal-body')
                  .html(
                    '<div class="alert alert-danger">' +
                      I18n(
                        'msg.cors_error',
                        'Please verify the following: <ul><li>If the image exist: %{url_img}</li> <li>Check if cors configuration are defined well, only for external images: S3, cloudfront(if you are using cloudfront).</li></ul><br> More information about CORS: <a href="%{url_blog}" target="_blank">here.</a>', { url_img: data.url, url_blog: 'http://blog.celingest.com/en/2014/10/02/tutorial-using-cors-with-cloudfront-and-s3/' }
                      ) +
                      '</div>'
                  )
              )
          }
        }

        if (mediaPanel.attr('data-dimension')) { // TODO: control dimensions
          const dim = mediaPanel.attr('data-dimension').split('x')
          if (dim[0]) {
            cropperData.data.width = parseFloat(dim[0].match(/\d+/)[0])
            fieldWidth.val(cropperData.data.width)
            if (dim[0].search(/\?/) > -1)
              fieldWidth.attr('max', cropperData.data.width)
            else
              fieldWidth.prop('readonly', true)
          }
          if (dim[1]) {
            cropperData.data.height = parseFloat(dim[1].match(/\d+/)[0])
            fieldHeight.val(cropperData.data.height)
            if (dim[1].search(/\?/) > -1)
              fieldHeight.attr('max', cropperData.data.height)
            else
              fieldHeight.prop('readonly', true)
          }
          if (dim[0] && (dim[0].search(/\?/) === -1) && dim[1] && (dim[1].search(/\?/) === -1))
            cropperData.aspectRatio = cropperData.data.width / cropperData.data.height
        }

        cropper = modal.find('img.editable').cropper(cropperData)
        return hideLoading()
      }
      , 300))
    }
    open_modal({
      zindex: 999991,
      id: 'media_panel_editor_image',
      title: I18n('button.edit_image', 'Edit Image') + ' - ' + data.name + (mediaPanel.attr('data-dimension') ? ' <small><i>(' + mediaPanel.attr('data-dimension') + ')</i></small>' : ''),
      content: '<div>' +
                '<div class="editable_wrapper">' +
                  '<img style="max-width: 100%" class="editable" id="media_editable_image" crossorigin src="' + data.url + '">' +
                '</div>' +
                '<div class="row" style="margin-top: 5px">' +
                  '<div class="col-md-8">' +
                    '<div class="editor_controls btn-group"></div>' +
                  '</div>' +
                  '<div class="col-md-4">' +
                    '<form class="export_image"> ' +
                      '<div class="input-group"><input class="form-control with_image data-error-place-parent required number" placeholder="Width"><span class="input-group-addon">x</span>' +
                      '<input class="form-control height_image data-error-place-parent required number" placeholder="Height"> ' +
                      '<span class="input-group-btn"><button class="btn btn-primary saveImage" type="submit"><i class="fa fa-save"></i> ' + I18n('button.save', 'Save Image') + '</button> </span> </div>' +
                    '</form>' +
                  '</div>' +
                '</div>' +
                '<!--span class="label label-default pull-right label_dimension"></span-->' +
              '</div>',
      callback: editCallback,
      modal_size: 'modal-lg'
    })
    return false
  })

  // upload from url form
  return mediaPanel.find('#cama_media_external').submit(function() {
    if (!$(this).valid())
      return false

    $.fn.upload_url({
      url: $(this).find('input').val(),
      skip_auto_crop: true,
      callback() { return mediaPanel.find('#cama_media_external')[0].reset() }
    })
    return false
  }).validate()
}

// return extra attributes for media panel
window.cama_media_get_custom_params = function(customSettings) {
  const mediaPanel = $('#cama_media_gallery')
  const r = eval('(' + mediaPanel.attr('data-extra-params') + ')')
  r.folder = mediaPanel.attr('data-folder')
  if (customSettings)
    $.extend(r, customSettings)

  r.folder = r.folder.replace(/\/{2,}/g, '/')
  return r
}

$(() =>
  // sample: $.fn.upload_url({url: 'http://camaleon.tuzitio.com/media/132/logo2.png', dimension: '120x120', versions: '200x200', folder: 'my_folder', thumb_size: '100x100'})
  // dimension: default current dimension
  // folder: default current folder
  // private: (Boolean) if true => list private files
  $.fn.upload_url = function(args) {
    const mediaPanel = $('#cama_media_gallery')
    const data = window.cama_media_get_custom_params({
      media_action: 'crop_url',
      onerror(message) {
        return $.fn.alert({ type: 'error', content: message, title: I18n('msg.error_uploading') })
      }
    })
    $.extend(data, args)
    const onError = data.onerror
    delete data.onerror
    showLoading()
    return $.post(mediaPanel.attr('data-url_actions'), data, function(resUpload) {
      hideLoading()
      if (resUpload.search('media_item') >= 0) { // success upload
        mediaPanel.trigger('add_file', { item: resUpload })
        if (data.callback)
          return data.callback(resUpload)
      } else
        return $.fn.alert({ type: 'error', content: resUpload, title: I18n('button.error') })
    }).error(() => $.fn.alert({ type: 'error', content: I18n('msg.internal_error'), title: I18n('button.error') }))
  }
)

// jquery library for modal uploader
$(() =>
  // sample: $.fn.upload_filemanager({title: "My title", formats: "image,video", dimension: "30x30", versions: '100x100,200x200', thumb_size: '100x100', selected: function(file){ alert(file["name"]) }})
  // file structure: {"name":"422.html","size":1547, "url":"http://localhost:3000/media/1/422.html", "format":"doc","type":"text/html"}
  // dimension: dimension: "30x30" | "x30" | dimension: "30x"
  // private: (boolean) if true => browser private files that are not possible access by public url
  $.fn.upload_filemanager = function(args) {
    args = args || {}
    if (args.formats === 'null')
      args.formats = ''

    if (args.dimension === 'null')
      args.dimension = ''

    if (args.versions === 'null')
      args.versions = ''

    if (args.thumb_size === 'null')
      args.thumb_size = ''

    return open_modal({
      title: args.title || I18n('msg.media_title'),
      id: 'cama_modal_file_uploader',
      modal_size: 'modal-lg',
      mode: 'ajax',
      url: root_admin_url + '/media/ajax',
      ajax_params: {
        media_formats: args.formats,
        dimension: args.dimension,
        versions: args.versions,
        thumb_size: args.thumb_size,
        private: args.private
      },
      callback(modal) {
        if (args.selected)
          window.callback_media_uploader = args.selected

        return modal.css('z-index', args.zindex || 99999).children('.modal-dialog').css('width', '90%')
      }
    })
  }
)

window.camaHumanFileSize = function(size) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB']
  let i = 0
  while (size >= 1024) {
    size /= 1024
    ++i
  }
  return size.toFixed(1) + ' ' + units[i]
}
