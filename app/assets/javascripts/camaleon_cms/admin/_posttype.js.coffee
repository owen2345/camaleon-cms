window['cama_init_posttype_form'] = ->
  form = $("#post_type_form");
  form.find('.unput_upload').input_upload();

  # permit hierarchy route only for post types enabled "Manage page hierarchy"
  form.find("[name='meta[has_parent_structure]']").change(->
    item = form.find("#meta_contents_route_format_hierarchy_post");
    item.parent().siblings().find("input").prop("disabled", $(this).is(":checked"))
    if($(this).is(":checked"))
      item.prop("checked", true).prop("disabled", false)
    else
      item.prop("disabled", true)
  ).trigger("change")

  form.find('[name="meta[has_picture]"]').change(->
    items = form.find('.picture_settings input')
    if($(this).is(":checked"))
      items.prop("disabled", false)
    else
      items.prop("disabled", true)
  ).trigger("change")