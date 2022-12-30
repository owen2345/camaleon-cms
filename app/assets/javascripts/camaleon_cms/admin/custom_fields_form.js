/* eslint-env jquery */
// add actions to assign custom fields to any model selected
jQuery(function($) {
  const panel = $('#cama_custom_field_form')
  const groupClassName = panel.attr('data-group_class_name')
  const $contentFields = $('#sortable-fields', panel)
  $contentFields.sortable({
    handle: '.panel-sortable'
  })
  let sluggerCount = $contentFields.children().length
  camaCustomFieldSetSlug()

  $('#content-items-default > a', panel).click(function() {
    const href = $(this).attr('href')
    showLoading()
    $.post(href, function(html) {
      hideLoading()
      const li = $('<li class="item">' + html + '</li>')
      $contentFields.append(li)
      camaCustomFieldSetSlug(li)
      const titleField = li.find('input.text-title')
      titleField.val(titleField.val() + '-' + (sluggerCount++))
      titleField.trigger('keyup')
      $('[data-toggle="tooltip"], a[title!=""]', $contentFields).tooltip()
    })
    return false
  })

  panel.on('click', '.panel-delete', function() {
    const parent = $(this).parents('.item:first')
    if (confirm(I18n('msg.delete_item')))
      parent.remove()

    return false
  })

  $('#select_assign_group', panel).change(function() {
    const option = $(this).find('option:checked')
    _changeAdditionalSelect(option)
    let txtHelp = option.data('help')
    if (txtHelp) txtHelp = '<div class="alert alert-info"><i class="fa fa-info-circle"></i>&nbsp; ' + txtHelp + ' </div>'
    $('#select_assign_group_help', panel).html(txtHelp)
    $('#select_assign_group_caption', panel).val(option.parent('optgroup').attr('label') + ' ' + option.text())
  }).val(_searchGroupClassName(groupClassName)).trigger('change')

  $('#select_post_simple', panel).change(function() {
    const option = $(this).find('option:checked')
    let txtHelp = option.data('help')
    if (txtHelp) txtHelp = '<div class="alert alert-info"><i class="fa fa-info-circle"></i>&nbsp; ' + txtHelp + ' </div>'
    $('#select_assign_group_help', panel).html(txtHelp)
    $('#select_assign_group_caption', panel).val(option.parent('optgroup').attr('label') + ': ' + option.text())
  }).val(groupClassName).trigger('change')

  $('#select_category_simple', panel).change(function() {
    const option = $(this).find('option:checked')
    let txtHelp = option.data('help')
    if (txtHelp) txtHelp = '<div class="alert alert-info"><i class="fa fa-info-circle"></i>&nbsp; ' + txtHelp + ' </div>'
    $('#select_assign_group_help', panel).html(txtHelp)
    $('#select_assign_group_caption', panel).val(option.parent('optgroup').attr('label') + ': ' + option.text())
  }).val(groupClassName).trigger('change')

  function _changeAdditionalSelect(option) {
    const optionValue = option.attr('value')
    const additionalOptions = ['_post_simple', '_category_simple']

    additionalOptions.forEach(function(key) {
      if (optionValue === additionalOptions[key])
        $('#select' + additionalOptions[key], panel).show().removeAttr('disabled')
      else
        $('#select' + additionalOptions[key], panel).hide().attr('disabled', 'disabled')
    })
  }

  function _searchGroupClassName(groupClassName) {
    /* eslint-disable-next-line eqeqeq */
    if (groupClassName.search('Post,') == 0)
      groupClassName = '_post_simple'
    /* eslint-disable-next-line eqeqeq */
    if (groupClassName.search('Category_Post,') == 0)
      groupClassName = '_category_simple'

    return groupClassName
  }

  function camaCustomFieldSetSlug(_panel) {
    $('.text-slug:not(.runned)', _panel || panel).each(function() {
      const $parent = $(this).parents('.panel-item')
      const $label = $parent.find('.span-title')
      $(this).slugify($parent.find('.text-title'), {
        slugFunc: function(str, originalFunc) {
          $label.html(str)
          return originalFunc(str)
        }
      })
      $(this).addClass('runned')
    })
  }
})
