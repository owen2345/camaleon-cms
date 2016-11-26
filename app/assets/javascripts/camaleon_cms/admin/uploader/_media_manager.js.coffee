window["cama_init_media"] = (media_panel) ->
  media_info = media_panel.find(".media_file_info")
  media_files_panel = media_panel.find(".media_browser_list")
  media_info_tab_info = media_panel.find(".media_file_info_col .nav-tabs .link_media_info")
  media_link_tab_upload = media_panel.find(".media_file_info_col .nav-tabs .link_media_upload")

  ################ visualize item
  # return the data of this file
  file_data = (item)->
    data = item.data('eval-data') || eval("("+item.find(".data_value").val()+")")
    item.data('eval-data', data)
    return data

  show_file = (item) ->
    item.addClass('selected').siblings().removeClass('selected')
    data = file_data(item)
    media_info_tab_info.click()
    tpl =
      "<div class='p_thumb'></div>" +
        "<div class='p_label'><b>"+I18n("button.name")+": </b><br> <span>"+data["name"]+"</span></div>" +
        "<div class='p_body'>" +
        "<div style='overflow: auto;'><b>"+I18n("button.url")+":</b><br> <a target='_blank' href='"+data["url"]+"'>"+data["url"]+"</a></div>" +
        "<div><b>"+I18n("button.size")+":</b> <span>"+cama_humanFileSize(data["size"])+"</span></div>" +
        "</div>"

    if window["callback_media_uploader"]
      if !media_panel.attr("data-formats") || (media_panel.attr("data-formats")  && ($.inArray(data["format"], media_panel.attr("data-formats").split(",")) >= 0 || $.inArray(data["url"].split(".").pop().toLowerCase(), media_panel.attr("data-formats").split(",")) >= 0))
        tpl += "<div class='p_footer'>" +
          "<button class='btn btn-primary insert_btn'>"+I18n("button.insert")+"</button>" +
          "</div>"

    media_info.html(tpl)
    media_info.find(".p_thumb").html(item.find(".thumb").html())
    if data["format"] == "image"
      draw_image = ->
        ww = parseInt(data['dimension'].split("x")[0])
        hh = parseInt(data['dimension'].split("x")[1])
        media_info.find(".p_body").append("<div class='cdimension'><b>"+I18n("button.dimension")+": </b><span>"+ww+"x"+hh+"</span></div>")
        if media_panel.attr("data-dimension") # verify dimensions
          btn = media_info.find(".p_footer .insert_btn")
          btn.prop('disabled', true)
          _ww = parseInt(media_panel.attr("data-dimension").split("x")[0]) || ww
          _hh = parseInt(media_panel.attr("data-dimension").split("x")[1]) || hh
          media_info.find('.cdimension').append("<span style='color: black;'> ==> "+media_panel.attr("data-dimension")+"</span>")
          if _ww == ww && _hh == hh
            btn.prop('disabled', false)
          else
            media_info.find(".cdimension").css("color", 'red')
            cut = $("<button class='btn btn-info pull-right'><i class='fa fa-crop'></i> "+I18n("button.crop_image")+"</button>").click(->
              $.fn.upload_url({url: data["url"]})
            )
            btn.after(cut)

      if !data['dimension'] && media_panel.attr("data-dimension") # if not dimension in the image and required dimension
        img = new Image()
        img.onload = ->
          data['dimension'] = this.width+'x'+this.height
          item.data('eval-data', data)
          draw_image()
        img.src = data["url"]
      else
        draw_image()

    if window["callback_media_uploader"] # trigger callback
      media_info.find(".insert_btn").click ->
        data["mime"] = data["type"]
        window["callback_media_uploader"](data)
        window["callback_media_uploader"] = null
        media_panel.closest(".modal").modal("hide")
        return false

  media_panel.on("click", ".file_item", ->
    show_file($(this))
    return false
  )

  media_files_panel.scroll(->
    if media_files_panel.attr('data-next-page') && $(this).scrollTop() + $(this).outerHeight() == $(this)[0].scrollHeight
      media_panel.trigger('navigate_to', {paginate: true, custom_params: {page: media_files_panel.attr('data-next-page')}})
  )
  # end visualize item

  ########## file uploader
  p_upload = media_panel.find(".cama_media_fileuploader")
  customFileData = ->
    return cama_media_get_custom_params()

  p_upload.uploadFile({
    url: p_upload.attr("data-url"),
    fileName: "file_upload",
    uploadButtonClass: "btn btn-primary btn-block",
    dragDropStr: '<span style="display: block;"><b>'+p_upload.attr('data-dragDropStr')+'</b></span>',
    uploadStr: p_upload.attr('data-uploadStr'),
    dynamicFormData: customFileData,
    onSuccess: ((files,res_upload,xhr,pd)->
      if res_upload.search("media_item") >= 0 # success upload
        media_panel.trigger("add_file", {item: res_upload, selected: $(pd.statusbar).siblings().not('.error_file_upload').size() == 0})
        $(pd.statusbar).remove();
      else
        $(pd.statusbar).find(".ajax-file-upload-progress").html("<span style='color: red;'>"+res_upload+"</span>");
    ),
    onError: ((files,status,errMsg,pd) ->
      $(pd.statusbar).addClass('error_file_upload').find(".ajax-file-upload-filename").append(" <i class='fa fa-times btn btn-danger btn-xs' onclick='$(this).closest(\".ajax-file-upload-statusbar\").remove();'></i>")
    )
  })
  ## end file uploader

  ######### folders breadcrumb
  media_panel.find(".media_folder_breadcrumb").on("click", "a", ->
    media_panel.trigger("navigate_to", {folder: $(this).attr("data-path")})
    return false
  )
  media_panel.on("click", ".folder_item", ->
    f = media_panel.attr("data-folder")+"/"+$(this).attr("data-key")
    if $(this).attr("data-key").search('/') >= 0
      f = $(this).attr("data-key")
    media_panel.trigger("navigate_to", {folder: f.replace(/\/{2,}/g, '/')})
  )
  media_panel.bind("update_breadcrumb", ->
    folder = media_panel.attr("data-folder").replace("//", "/")
    folder_prefix = []
    if folder == "/" || folder == ""
      folder_items = ["/"]
    else
      folder_items = folder.split("/")
    breadrumb = []
    for value, index in folder_items
      name = value
      if value == "/" || value == ""
        name = I18n("button.root")
      if index == folder_items.length - 1
        breadrumb.push("<li><span>"+name+"</span></li>")
      else
        folder_prefix.push(value)
        breadrumb.push("<li><a data-path='"+(folder_prefix.join("/") || "/").replace(/\/{2,}/g, '/')+"' href='#'>"+name+"</a></li>")
    media_panel.find(".media_folder_breadcrumb").html(breadrumb.join(""))
  ).trigger("update_breadcrumb")
  ## end folders

  ######### folder navigation
  media_panel.bind("navigate_to", (e, data)->
    if data["folder"]
      media_panel.attr("data-folder", data["folder"])
    folder = media_panel.attr("data-folder")
    media_panel.trigger("update_breadcrumb")
    req_params = cama_media_get_custom_params({partial: true, folder: folder})
    if data["paginate"]
      req_params = media_panel.data('last_req_params') || req_params
    else
      media_info.html("")
      media_link_tab_upload.click()

    media_panel.data('last_req_params', $.extend({}, req_params, data['custom_params'] || {}))
    showLoading()
    $.getJSON(media_panel.attr("data-url"), media_panel.data('last_req_params'), (res)->
      if data["paginate"]
        last_folder = media_files_panel.children('.folder_item:last')
        if last_folder.length ==1 then last_folder.after(res.html) else  media_files_panel.append(res.html)
      else
        media_files_panel.html(res.html)
      media_files_panel.attr('data-next-page', res.next_page)
      hideLoading()
    )
  ).bind("add_file", (e,  data)-> # add html item in the list
    item = $(data["item"]).hide()
    last_folder = media_files_panel.children('.folder_item:last')
    if last_folder.length ==1 then last_folder.after(item) else media_files_panel.prepend(item)
    if data["selected"] == true || data["selected"] == undefined
      item.click()
    media_files_panel.scrollTop(0)
    item.fadeIn(1500)
  )

  # search file
  media_panel.find('#cama_search_form').submit ->
    media_panel.trigger('navigate_to', {custom_params: {search: $(this).find('input:text').val()}})
    return false

  # reload current directory
  media_panel.find('.cam_media_reload').click (e, data)->
    media_panel.trigger('navigate_to', {custom_params:{cama_media_reload: $(this).attr('data-action')}})
    e.preventDefault()

  # element actions
  media_panel.on("click", "a.add_folder", ->
    content = $("<form id='add_folder_form'><div><label for=''>"+I18n('button.folder')+": </label> <div class='input-group'><input name='folder' class='form-control required' placeholder='Folder name..'><span class='input-group-btn'><button class='btn btn-primary' type='submit'>"+I18n('button.create')+"</button></span></div></div> </form>")
    callback = (modal)->
      btn = modal.find(".btn-primary")
      input = modal.find("input").keyup(->
        if $(this).val()
          btn.removeAttr("disabled")
        else
          btn.attr("disabled", "true")
      ).trigger("keyup")
      modal.find("form").submit ->
        showLoading()
        $.post(media_panel.attr("data-url_actions"), cama_media_get_custom_params({folder: media_panel.attr("data-folder")+"/"+input.val(), media_action: "new_folder"}), (res)->
          hideLoading()
          modal.modal("hide")
          if res.search("folder_item") >= 0 # success upload
            media_files_panel.append(res)
          else
            $.fn.alert({type: 'error', content: res, title: "Error"})
        )
        return false
    open_modal({title: "New Folder", content: content, callback: callback, zindex: 9999999})
    return false
  )

  # destroy file and folder
  media_panel.on("click", "a.del_item, a.del_folder", ->
    unless confirm(I18n("msg.delete_item"))
      return false
    link = $(this)
    item = link.closest(".media_item")
    showLoading()
    $.post(media_panel.attr("data-url_actions"), cama_media_get_custom_params({folder: media_panel.attr("data-folder")+"/"+item.attr("data-key"), media_action: if link.hasClass("del_folder") then "del_folder" else "del_file"}), (res)->
      hideLoading()
      if res
        $.fn.alert({type: 'error', content: res, title: I18n("button.error")})
      else
        item.remove()
        media_info.html("")
    ).error(->
      $.fn.alert({type: 'error', content: I18n("msg.internal_error"), title: I18n("button.error")})
    )
    return false
  )

  # edit image
  media_panel.on('click', '.edit_item', ->
    link = $(this)
    item = link.closest(".media_item")
    data = file_data(item)
    cropper = null
    cropper_data = null

    edit_callback = (modal)->
      save_image = (name, same_name)->
        $.fn.upload_url({url: cropper.cropper('getCroppedCanvas').toDataURL('image/jpeg'), name: name, same_name: same_name, callback: (res)->
          modal.modal('hide')
        })

      # add buttons
      for icon, cmd of {arrows: "('setDragMode', 'move')", crop: "('setDragMode', 'crop')", 'search-plus': "('zoom', 0.1)", 'search-minus': "('zoom', -0.1)", 'arrow-left': "('move', -10, 0)", 'arrow-right': "('move', 10, 0)", 'arrow-up': "('move', 0, -10)", 'arrow-down': "('move', 0, 10)", 'rotate-left': "('rotate', -45)", 'rotate-right': "('rotate', 45)", 'arrows-h': "('scaleX', -1)", 'arrows-v': "('scaleY', -1)", refresh: "('reset')"}
        btn = $('<button type="button" class="btn btn-default" data-cmd="'+cmd+'"><i class="fa fa-'+icon+'"></i></button>')
        modal.find('.editor_controls').append(btn)
        btn.click(->
          btn = $(this)
          cmd = btn.data('cmd')
          if cmd == "('scaleY', -1)" || cmd == "('scaleX', -1)"
            btn.data('cmd', cmd.replace('-1', '1'))
          else if cmd == "('scaleY', 1)" || cmd == "('scaleX', 1)"
            btn.data('cmd', cmd.replace('1', '-1'))
          eval('cropper.cropper'+cmd)
          if cmd == "('reset')"
            cropper.cropper('setData', cropper_data['data'])
        )

      # save editted image
      save_btn = $('<button type="button" class="btn btn-default"><i class="fa fa-save"></i> '+I18n('button.save', 'Save Image')+'</button>').click(->
        save_buttons = (modal2)->
          modal2.find('img.preview').attr('src', cropper.cropper('getCroppedCanvas').toDataURL('image/jpeg'))
          modal2.find('.save_btn').click(->
            save_image(data['name'], true)
            modal2.modal('hide')
            item.remove()
          )
          modal2.find('form').validate({submitHandler: ->
            save_image(modal2.find('.file_name').val()+'.'+data['name'].split('.').pop())
            modal2.modal('hide')
            return false
          })
        open_modal({zindex: 999992, id: 'media_preview_editted_image', content: '<div class="text-center" style="overflow: auto;"><img class="preview"></div><br><div class="row"><div class="col-md-4">'+(if link.attr('data-permit-overwrite') then '<button class="btn save_btn btn-default">'+I18n('button.replace_image')+'</button>' else '')+'</div><div class="col-md-8"><form class="input-group"><input type="text" class="form-control file_name required" name="file_name"><div class="input-group-btn"><button class="btn btn-primary" type="submit">'+I18n('button.save_new_image')+'</button></div></form></div></div>', callback: save_buttons})
      )
      modal.find('.editor_controls').append(save_btn)

      # show cropper image
      showLoading()
      modal.find('img.editable').load(->
        setTimeout(->
          label = modal.find('.label_dimension')
          cropper_data = {data: {}, minContainerHeight: 450, modal: true, crop: (e)->
            dim = cropper_data['data']['dim']
            r = false
            if dim && dim[0].search(/\?/) > -1 && parseFloat(dim[0].match(/\d+/)[0]) < e.width # max width
              cropper.cropper('setData', {width: parseFloat(dim[0].match(/\d+/)[0])})
              r = true

            if dim && dim[1].search(/\?/) > -1 && parseFloat(dim[1].match(/\d+/)[0]) < e.height # max height
              cropper.cropper('setData', {height: parseFloat(dim[1].match(/\d+/)[0])})
              r = true

            if dim && dim[0] && dim[0].search(/\?/) == -1 && e.width != parseFloat(dim[0]) # same width
              cropper.cropper('setData', {width: parseFloat(dim[0])})
              r = true

            if dim && dim[1] && dim[1].search(/\?/) == -1 && e.height != parseFloat(dim[1]) # same width
              cropper.cropper('setData', {height: parseFloat(dim[1])})
              r = true

            unless r
              label.html(Math.round(e.width) + " x "+Math.round(e.height))
          , built: ()->
            if modal.find('.cropper-canvas img').attr('crossorigin')
              modal.find('.modal-body').html('<div class="alert alert-danger">'+I18n('msg.cors_error', 'Please verify the following: <ul><li>If the image exist: %{url_img}</li> <li>Check if cors configuration are defined well, only for external images: S3, cloudfront(if you are using cloudfront).</li></ul><br> More information about CORS: <a href="%{url_blog}" target="_blank">here.</a>', {url_img: data['url'], url_blog: 'http://blog.celingest.com/en/2014/10/02/tutorial-using-cors-with-cloudfront-and-s3/'})+'</div>')
          }

          if media_panel.attr("data-dimension") # TODO: control dimensions
            dim = media_panel.attr("data-dimension").split('x')
            cropper_data['data']['dim'] = dim
            if dim[0]
              cropper_data['data']['width'] = parseFloat(dim[0].match(/\d+/)[0])
            if dim[1]
              cropper_data['data']['height'] = parseFloat(dim[1].match(/\d+/)[0])
            if dim[0] && dim[0].search(/\?/) == -1 && dim[1] && dim[1].search(/\?/) == -1
              cropper_data['cropBoxResizable'] = false
              cropper_data['zoomable'] = false

          cropper = modal.find('img.editable').cropper(cropper_data)
          hideLoading()
        , 300)
      )
    open_modal({zindex: 999991, id: 'media_panel_editor_image', title: 'Edit Image - ' + data['name'], content: '<div><div class="editable_wrapper"><img style="max-width: 100%;" class="editable" id="media_editable_image" src="'+data['url']+'"></div><div class="editor_controls btn-group"></div><span class="label label-default pull-right label_dimension"></span></div>', callback: edit_callback, modal_size: 'modal-lg'})
    return false
  )

  # upload from url form
  media_panel.find("#cama_media_external").submit( ->
    unless $(this).valid()
      return false
    $.fn.upload_url({url: $(this).find("input").val(), callback: ->
      media_panel.find("#cama_media_external")[0].reset();
    })
    return false
  ).validate()

# return extra attributes for media panel
window['cama_media_get_custom_params'] = (custom_settings)->
  media_panel = $("#cama_media_gallery")
  r = eval("("+media_panel.attr('data-extra-params')+")")
  r['folder'] = media_panel.attr("data-folder")
  if custom_settings
    $.extend(r, custom_settings)
  r['folder'] = r['folder'].replace(/\/{2,}/g, '/')
  return r

$ ->
  # sample: $.fn.upload_url({url: 'http://camaleon.tuzitio.com/media/132/logo2.png', dimension: '120x120', versions: '200x200', folder: 'my_folder', thumb_size: '100x100'})
  # dimension: default current dimension
  # folder: default current folder
  # private: (Boolean) if true => list private files
  $.fn.upload_url = (args)->
    media_panel = $("#cama_media_gallery")
    data = cama_media_get_custom_params({media_action: "crop_url", onerror: (message) ->
      $.fn.alert({type: 'error', content: message, title: I18n("msg.error_uploading")})
    })
    $.extend(data, args); on_error = data["onerror"]; delete data["onerror"];
    showLoading()
    $.post(media_panel.attr("data-url_actions"), data, (res_upload)->
      hideLoading()
      if res_upload.search("media_item") >= 0 # success upload
        media_panel.trigger("add_file", {item: res_upload})
        if data["callback"]
          data["callback"](res_upload)
      else
        $.fn.alert({type: 'error', content: res_upload, title: I18n("button.error")})
    ).error(->
      $.fn.alert({type: 'error', content: I18n("msg.internal_error"), title: I18n("button.error")})
    )


# jquery library for modal uploader
$ ->
  # sample: $.fn.upload_filemanager({title: "My title", formats: "image,video", dimension: "30x30", versions: '100x100,200x200', thumb_size: '100x100', selected: function(file){ alert(file["name"]) }})
  # file structure: {"name":"422.html","size":1547, "url":"http://localhost:3000/media/1/422.html", "format":"doc","type":"text/html"}
  # dimension: dimension: "30x30" | "x30" | dimension: "30x"
  # private: (boolean) if true => browser private files that are not possible access by public url
  $.fn.upload_filemanager = (args)->
    args = args || {}
    open_modal({title: args["title"] || I18n("msg.media_title"), id: 'cama_modal_file_uploader', modal_size: "modal-lg", mode: "ajax", url: root_admin_url+"/media/ajax", ajax_params: {media_formats: args["formats"], dimension: args["dimension"], versions: args["versions"], thumb_size: args["thumb_size"], private: args['private'] }, callback: (modal)->
      if args["selected"]
        window["callback_media_uploader"] = args["selected"]
      modal.css("z-index", args["zindex"] || 99999).children(".modal-dialog").css("width", "90%")
    })

window['cama_humanFileSize'] = (size)->
  units = ['B', 'KB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB'];
  i = 0;
  while(size >= 1024)
    size /= 1024;
    ++i;
  return size.toFixed(1) + ' ' + units[i];
