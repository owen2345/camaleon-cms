$ ->
  panel = $('#menu_content')
  menu_form = $('#menu_form')
  list_panel = $('#menus_list')
  menu_items_available = $('#menu_items')
  list_panel.nestable()

  # reorder items
  last_data = {items: list_panel.nestable("serialize")}
  list_panel.on('change', ->
    data = {items: list_panel.nestable("serialize")}
    if JSON.stringify(last_data) == JSON.stringify(data)
      return
    panel.find('#menu_reoreder_loading').show()
    $.post(list_panel.attr('data-reorder_url'), data, (res)->
      last_data = data
      panel.find('#menu_reoreder_loading').hide()
      if res
        alert(res)
    )
  )

  # save a new menu item into DB
  save_menu = (data)->
    showLoading()
    $.post(list_panel.attr('data-url'), data, (res)->
      list_panel.children('.dd-list').append($(res).children())
      hideLoading()
    )

  # add menu items (non-external)
  menu_items_available.find(".add_links_to_menu").click ->
    data = {items: [], authenticity_token: menu_form.find('[name="authenticity_token"]').val()}
    flag =false
    $(this).closest('.panel').find('input:checkbox:checked').each(->
      flag = true
      data['items'].push({id: $(this).val(), kind: $(this).closest('.class_type').attr('data-type')})
    ).prop('checked', false)

    unless flag
      return false
    save_menu(data)
    return false

  # add custom menu items (non-external)
  menu_items_available.find(".add_links_custom_to_menu").click ->
    data = {custom_items: [], authenticity_token: menu_form.find('[name="authenticity_token"]').val()}
    flag =false
    $(this).closest('.panel').find('input:checkbox:checked').each(->
      flag = true
      data['custom_items'].push({url: $(this).val(), kind: $(this).attr('data-kind'), label: $(this).attr('data-label')})
    ).prop('checked', false)

    unless flag
      return false
    save_menu(data)
    return false

  # add external link
  menu_items_available.find('.form-custom-link').submit ->
    form = $(this)
    unless form.valid()
      return false
    save_menu({external: form.serializeObject()})
    this.reset()
    setTimeout(->
      form.find('label.error').hide()
    , 100)
    return false

  # edit external menu items
  list_panel.on('click', '.item_external', ->
    link = $(this)
    open_modal({title: link.attr('data-original-title') || link.attr('title'), url: link.attr('href'), mode: 'ajax', callback: (modal)->
      form = modal.find('form')
      init_form_validations(form);
      form.submit(->
        unless form.valid()
          return false
        showLoading()
        $.post(form.attr('action'), form.serialize(), (res)->
          link.closest('li').replaceWith($(res).html())
          modal.modal("hide")
          hideLoading()
        )
        return false
      )
    })
    return false
  )

  # delete menu items
  list_panel.on('click', '.delete_menu_item', ->
    link = $(this)
    unless confirm(I18n('msg.confirm_del', 'Are you sure to delete this item?'))
      return false
    showLoading()
    $.get(link.attr('href'), ->
      link.closest('.dd-item').remove()
      hideLoading()
    )
    return false
  )

  # new menu
  panel.find('.new_menu_link, .edit_menu_link').ajax_modal({callback: (modal)->
    form = modal.find('form')
    setTimeout(->
      init_form_validations(form)
    ,1000)
  })

  # menus list - change dropdown
  panel.find('#menu_items #switch_nav_menu_form select').change ->
    unless $(this).val()
      return
    $(this).closest('form').submit()

  # custom fields
  list_panel.on('click', '.custom_settings_link', ->
    link = $(this)
    open_modal({title: link.attr('data-original-title') || link.attr('title'), url: link.attr('href'), mode: 'ajax', callback: (modal)->
      form = modal.find('form')
      init_form_validations(form);
      form.submit(->
        unless form.valid()
          return false
        showLoading()
        $.post(form.attr('action'), form.serialize(), (res)->
          if res
            alert(res)
          modal.modal("hide")
          hideLoading()
        )
        return false
      )
    })
    return false
  )