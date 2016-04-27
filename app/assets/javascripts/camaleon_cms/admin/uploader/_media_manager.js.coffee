window["cama_init_media"] = (media_panel) ->
  media_info = media_panel.find(".media_file_info")
  media_info_tab_info = media_panel.find(".media_file_info_col .nav-tabs .link_media_info")
  media_link_tab_upload = media_panel.find(".media_file_info_col .nav-tabs .link_media_upload")

  ################ visualize item
  show_file = (item) ->
    item.addClass('selected').siblings().removeClass('selected')
    data = eval("("+item.find(".data_value").val()+")")
    media_info_tab_info.click()
    tpl =
      "<div class='p_thumb'></div>" +
        "<div class='p_label'><b>"+I18n("button.name")+": </b><br> <span>"+data["name"]+"</span></div>" +
        "<div class='p_body'>" +
        "<div><b>"+I18n("button.url")+":</b><br> <a target='_blank' href='"+data["url"]+"'>"+data["url"]+"</a></div>" +
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
      ww = parseInt(data['dimension'].split("x")[0])
      hh = parseInt(data['dimension'].split("x")[1])
      media_info.find(".p_body").append("<div class='cdimension'><b>"+I18n("button.dimension")+": </b><span>"+ww+"x"+hh+"</span></div>")
      if media_panel.attr("data-dimension") # verify dimensions
        btn = media_info.find(".p_footer .insert_btn")
        btn.prop('disabled', true)
        _ww = parseInt(media_panel.attr("data-dimension").split("x")[0])
        _hh = parseInt(media_panel.attr("data-dimension").split("x")[1])
        if _ww == ww && _hh == hh
          btn.prop('disabled', false)
        else
          media_info.find(".cdimension").css("color", 'red')
          cut = $("<button class='btn btn-info pull-right'><i class='fa fa-crop'></i> "+I18n("button.crop_image")+"</button>").click(->
            $.fn.upload_url({url: data["url"]})
          )
          btn.after(cut)

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
  # end visualize item

  ########## file uploader
  p_upload = media_panel.find(".cama_media_fileuploader")
  customFileData = ->
    return {folder: media_panel.attr("data-folder").replace(/\/{2,}/g, '/'), formats: media_panel.attr("data-formats") }

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
    media_info.html("")
    media_link_tab_upload.click()

    showLoading()
    $.get(media_panel.attr("data-url"), {folder: folder.replace(/\/{2,}/g, '/'), partial: true, media_formats: media_panel.attr("data-formats")}, (res)->
      media_panel.find(".media_browser_list").html(res)
      hideLoading()
    )
  ).bind("add_file", (e,  data)-> # add html item in the list
    item = $(data["item"])
    media_panel.find(".media_browser_list").prepend(item)
    if data["selected"] == true || data["selected"] == undefined
      item.click()
  )

  # search file
  media_panel.find('#cama_search_form').submit ->
    showLoading()
    $.get(media_panel.attr("data-url"), {search: $(this).find('input:text').val(), partial: true, media_formats: media_panel.attr("data-formats")}, (res)->
      media_panel.find(".media_browser_list").html(res)
      hideLoading()
    )
    return false

  # reload current directory
  media_panel.find('.cam_media_reload').click (e)->
    showLoading()
    $.get(media_panel.attr("data-url"), {partial: true, media_formats: media_panel.attr("data-formats"), folder: media_panel.attr("data-folder"), cama_media_reload: $(this).attr('data-action')}, (res)->
      media_panel.find(".media_browser_list").html(res)
      hideLoading()
    )
    e.preventDefault()

  # element actions
  media_panel.on("click", "a.add_folder", ->
    content = $("<form><div><label for=''>"+I18n('button.folder')+": </label> <div class='input-group'><input name='folder' class='form-control required' placeholder='Folder name..'><span class='input-group-btn'><button class='btn btn-primary' type='submit'>"+I18n('button.create')+"</button></span></div></div> </form>")
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
        $.post(media_panel.attr("data-url_actions"), {folder: media_panel.attr("data-folder")+"/"+input.val().replace(/\/{2,}/g, '/'), media_action: "new_folder"}, (res)->
          hideLoading()
          modal.modal("hide")
          if res.search("folder_item") >= 0 # success upload
            media_panel.find(".media_browser_list").append(res)
          else
            $.fn.alert({type: 'error', content: res, title: "Error"})
        )
        return false
    open_modal({title: "New Folder", content: content, callback: callback})
    return false
  )

  # destroy file and folder
  media_panel.on("click", "a.del_item, a.del_folder", ->
    unless confirm(I18n("msg.delete_item"))
      return false
    link = $(this)
    item = link.closest(".media_item")
    showLoading()
    $.post(media_panel.attr("data-url_actions"), {folder: media_panel.attr("data-folder")+"/"+item.attr("data-key").replace(/\/{2,}/g, '/'), media_action: if link.hasClass("del_folder") then "del_folder" else "del_file"}, (res)->
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

  # upload from url form
  media_panel.find("#cama_media_external").submit( ->
    unless $(this).valid()
      return false
    $.fn.upload_url({url: $(this).find("input").val(), callback: ->
      media_panel.find("#cama_media_external")[0].reset();
    })
    return false
  ).validate()

$ ->
  # sample: $.fn.upload_url({url: 'http://camaleon.tuzitio.com/media/132/logo2.png', dimension: '120x120', folder: 'my_folder'})
  # dimension: default current dimension
  # folder: default current folder
  $.fn.upload_url = (args)->
    media_panel = $("#cama_media_gallery")
    data = {folder: media_panel.attr("data-folder").replace(/\/{2,}/g, '/'), media_action: "crop_url", formats: media_panel.attr("data-formats"), onerror: (message) ->
      $.fn.alert({type: 'error', content: message, title: I18n("msg.error_uploading")})
    }
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


# jquery library for modal updaloder
$ ->
  # sample: $.fn.upload_filemanager({title: "My title", formats: "image,video", dimension: "30x30", selected: function(file){ alert(file["name"]) }})
  # file structure: {"name":"422.html","size":1547, "url":"http://localhost:3000/media/1/422.html", "format":"doc","type":"text/html"}
  # dimension: dimension: "30x30" | "x30" | dimension: "30x"
  $.fn.upload_filemanager = (args)->
    args = args || {}
    open_modal({title: args["title"] || I18n("msg.media_title"), id: 'cama_modal_file_uploader', modal_size: "modal-lg", mode: "ajax", url: root_admin_url+"/media/ajax", ajax_params: {media_formats: args["formats"], dimension: args["dimension"] }, callback: (modal)->
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
