window["cama_init_media"] = (media_panel)->
  media_info = media_panel.find(".media_file_info")
  media_info_tab_info = media_panel.find(".media_file_info_col .nav-tabs .link_media_info")
  media_link_tab_upload = media_panel.find(".media_file_info_col .nav-tabs .link_media_upload")

  ################ visualize item
  show_file = (item) ->
    data = eval("("+item.find(".data_value").val()+")")
    media_info_tab_info.click()
    tpl =
      "<div class='p_thumb'></div>" +
      "<div class='p_label'><b>Name: </b><br> <span>"+data["name"]+"</span></div>" +
      "<div class='p_body'>" +
        "<div><b>Url:</b><br> <a target='_blank' href='"+data["url"]+"'>"+data["url"]+"</a></div>" +
        "<div><b>Size:</b><br> <span>"+data["size"]+"</span></div>" +
      "</div>"

    if window["callback_media_uploader"]
      tpl += "<div class='p_footer'>" +
          "<a href='#' class='btn btn-primary insert_btn'>Insert</a>" +
          "</div>"

    media_info.html(tpl)
    media_info.find(".p_thumb").html(item.find(".thumb").html())

    if window["callback_media_uploader"] # trigger callback
      media_info.find(".insert_btn").click ->
        data["mime"] = data["type"]
        window["callback_media_uploader"](data)
        window["callback_media_uploader"] = null
        return false

  media_panel.on("click", ".file_item", ->
    show_file($(this))
    return false
  )
  # end visualize item

  ########## file uploader
  p_upload = media_panel.find(".cama_media_fileuploader")
  customFileData = ->
    return {folder: media_panel.attr("data-folder") }

  p_upload.uploadFile({
    url: p_upload.attr("data-url"),
    fileName: "file_upload",
    dynamicFormData: customFileData,
    onSuccess: (files,res_upload,xhr,pd)->
      if res_upload.search("<") == 0 # success upload
        $(pd.statusbar).remove();
        media_panel.find(".media_browser_list").prepend(res_upload).children().first().click()

      else
        $(pd.statusbar).find(".ajax-file-upload-progress").html("<span style='color: red;'>"+res_upload+"</span>");
  })
  ## end file uploader

  ######### folders breadcrumb
  media_panel.find(".media_folder_breadcrumb").on("click", "a", ->
    media_panel.trigger("navigate_to", {folder: $(this).attr("data-path")})
  )
  media_panel.on("click", ".folder_item", ->
    media_panel.trigger("navigate_to", {folder: media_panel.attr("data-folder")+"/"+$(this).attr("data-key")})
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
        name = "root"
      if index == folder_items.length - 1
        breadrumb.push("<li><span>"+name+"</span></li>")
      else
        folder_prefix.push(value)
        breadrumb.push("<li><a data-path='"+(folder_prefix.join("/") || "/")+"' href='#'>"+name+"</a></li>")
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
    $.get(media_panel.attr("data-url"), {folder: folder, partial: true, media_formats: media_panel.attr("data-formats")}, (res)->
      media_panel.find(".media_browser_list").html(res)
      hideLoading()
    )
  )

# jquery library for modal updaloder
$ ->
  # sample: $.fn.upload_filemanager({title: "My title", formats: "image,video", selected: function(file){ alert(file["name"]) }})
  # file structure: {"name":"422.html","size":1547, "url":"http://localhost:3000/media/1/422.html", "format":"doc","type":"text/html"}
  $.fn.upload_filemanager = (args)->
    args = args || {}
    open_modal({title: args["title"] || "Media Uploader", modal_size: "modal-lg", mode: "ajax", url: root_url+"/admin/media/ajax", ajax_params: {media_formats: args["formats"]}, callback: (modal)->
      if args["selected"]
        window["callback_media_uploader"] = args["selected"]
      modal.children(".modal-dialog").css("width", "90%")
    })