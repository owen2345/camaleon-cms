/* eslint-env jquery */
$(function() {
  const panel = $('#menu_content')
  const menuForm = $('#menu_form')
  const listPanel = $('#menus_list')
  const menuItemsAvailable = $('#menu_items')

  listPanel.nestable()

  // reorder items
  let lastData = { items: listPanel.nestable('serialize') }
  listPanel.on('change', function() {
    const data = { items: listPanel.nestable('serialize') }
    if (JSON.stringify(lastData) === JSON.stringify(data))
      return

    panel.find('#menu_reoreder_loading').show()
    $.post(listPanel.attr('data-reorder_url'), data, function(res) {
      lastData = data
      panel.find('#menu_reoreder_loading').hide()
      if (res)
        alert(res)
    })
  })

  // save a new menu item into DB
  const saveMenu = function(data) {
    showLoading()

    $.post(listPanel.attr('data-url'), data, function(res) {
      listPanel.children('.dd-list').append($(res).children())
      hideLoading()
    })
  }

  // add menu items (non-external)
  menuItemsAvailable.find('.add_links_to_menu').click(function() {
    const data = { items: [], authenticity_token: menuForm.find('[name="authenticity_token"]').val() }
    let flag = false
    $(this).closest('.panel').find('input:checkbox:checked').each(function() {
      flag = true
      data.items.push({ id: $(this).val(), kind: $(this).closest('.class_type').attr('data-type') })
    }).prop('checked', false)

    if (!flag)
      return false

    saveMenu(data)
    return false
  })

  // add custom menu items (non-external)
  menuItemsAvailable.find('.add_links_custom_to_menu').click(function() {
    const data = { custom_items: [], authenticity_token: menuForm.find('[name="authenticity_token"]').val() }
    let flag = false
    $(this).closest('.panel').find('input:checkbox:checked').each(function() {
      flag = true
      data.custom_items.push({ url: $(this).val(), kind: $(this).attr('data-kind'), label: $(this).attr('data-label') })
    }).prop('checked', false)

    if (!flag)
      return false

    saveMenu(data)
    return false
  })

  // add external link
  menuItemsAvailable.find('.form-custom-link').submit(function() {
    const form = $(this)
    if (!form.valid())
      return false

    saveMenu({ external: form.serializeObject() })
    this.reset()
    setTimeout(() => form.find('label.error').hide(), 100)
    return false
  })

  // edit external menu items
  listPanel.on('click', '.item_external', function() {
    const link = $(this)
    open_modal({
      title: link.attr('data-original-title') || link.attr('title'),
      url: link.attr('href'),
      mode: 'ajax',
      callback: (modal) => {
        const form = modal.find('form')
        init_form_validations(form)
        form.submit(function() {
          if (!form.valid())
            return false

          showLoading()
          $.post(form.attr('action'), form.serialize(), function(res) {
            link.closest('li').replaceWith($(res).html())
            modal.modal('hide')
            hideLoading()
          })
          return false
        })
      }
    })
    return false
  })

  // delete menu items
  listPanel.on('click', '.delete_menu_item', function() {
    const link = $(this)
    if (!confirm(I18n('msg.confirm_del', 'Are you sure to delete this item?')))
      return false

    showLoading()
    $.get(link.attr('href'), function() {
      link.closest('.dd-item').remove()
      hideLoading()
    })
    return false
  })

  // new menu
  panel.find('.new_menu_link, .edit_menu_link').ajax_modal({
    callback: (modal) => {
      const form = modal.find('form')

      setTimeout(() => init_form_validations(form), 1000)
    }
  })

  // menus list - change dropdown
  panel.find('#menu_items #switch_nav_menu_form select').change(function() {
    if (!$(this).val())
      return

    $(this).closest('form').submit()
  })

  // custom fields
  listPanel.on('click', '.custom_settings_link', function() {
    const link = $(this)
    open_modal({
      title: link.attr('data-original-title') || link.attr('title'),
      url: link.attr('href'),
      mode: 'ajax',
      callback: (modal) => {
        const form = modal.find('form')
        init_form_validations(form)
        form.submit(function() {
          if (!form.valid())
            return false

          showLoading()
          $.post(form.attr('action'), form.serialize(), function(res) {
            if (res)
              alert(res)

            modal.modal('hide')
            hideLoading()
          })
          return false
        })
      }
    })
    return false
  })
})
