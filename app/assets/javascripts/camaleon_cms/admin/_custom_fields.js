// build custom field groups with values recovered from DB received in field_values
/* eslint-env jquery */
// eslint-disable-next-line no-unused-vars
function BuildCustomFieldGroup(fieldValues, groupId, fieldsData, isRepeat, fieldNameGroup) {
  if (fieldValues.length === 0)
    fieldValues = [{}]

  const groupPanel = $('#custom_field_group_' + groupId)
  const groupPanelBody = groupPanel.find(' > .panel-body')
  const groupClone = groupPanelBody.children('.custom_sortable_grouped').clone().removeClass('hidden')
  let fieldGroupCounter = 0

  groupPanelBody.children('.custom_sortable_grouped').remove()

  function AddGroup(values) {
    const clone = groupClone.clone()
    clone
      .find('input, textarea, select')
      .not('.code_style')
      .each(
        function() {
          $(this).attr(
            'name', $(this).attr('name').replace(fieldNameGroup, fieldNameGroup + '[' + fieldGroupCounter + ']')
          )
        }
      )
    groupPanelBody.append(clone)
    groupPanel.trigger('update_custom_group_number')
    for (const k in fieldsData)
      CamaBuildCustomField(clone.find('.content-field-' + fieldsData[k].id), fieldsData[k], values[k])

    if (fieldGroupCounter === 0) clone.children('.header-field-grouped').find('.del').remove()
    fieldGroupCounter++
    return false
  }

  if (isRepeat) {
    groupPanelBody.sortable({
      handle: '.move.fa-arrows',
      items: ' > .custom_sortable_grouped',
      update: function() { groupPanel.trigger('update_custom_group_number') },
      start: function(e, ui) { // fix tinymce
        $(ui.item).find('.mce-panel').each(function() {
          tinymce.execCommand('mceRemoveEditor', false, $(this).next().addClass('cama_restore_editor').attr('id'))
        })
      },
      stop: function(e, ui) { // fix tinymce
        $(ui.item).find('.cama_restore_editor').each(function() {
          tinymce.execCommand('mceAddEditor', true, $(this).attr('id'))
        })
      }
    })
    groupPanel.find('.btn.duplicate_cutom_group').click(AddGroup)
    groupPanelBody.on('click', '.header-field-grouped .del', function() { if (confirm(I18n('msg.delete_item'))) $(this).closest('.custom_sortable_grouped').fadeOut('slow', function() { $(this).remove(); groupPanel.trigger('update_custom_group_number') }); return false })
    groupPanelBody.on('click', '.header-field-grouped .toggleable', function() {
      if ($(this).hasClass('fa-angle-down')) $(this).removeClass('fa-angle-down').addClass('fa-angle-up').closest('.header-field-grouped').next().slideUp()
      else $(this).removeClass('fa-angle-up').addClass('fa-angle-down').closest('.header-field-grouped').next().slideDown()
      return false
    })
    groupPanel.bind('update_custom_group_number', function() { $(this).find('.custom_sortable_grouped').each(function(index) { $(this).find('input.cama_custom_group_number').val(index) }) })
    $.each(fieldValues, function(fieldVal, key) { AddGroup(this) })
  } else
    AddGroup(fieldValues[0])
}

function CamaBuildCustomField(panel, fieldData, values) {
  values = values || []
  let fieldCounter = 0
  const $field = panel.clone().wrap('li')

  panel.html(
    "<div class='cama_w_custom_fields'></div>" +
      (fieldData.multiple ? "<div class='field_multiple_btn'> <a href='#' class='btn btn-warning btn-xs'> <i class='fa fa-plus'></i> " + panel.attr('data-add_field_title') + '</a></div>' : '')
  )

  const fieldActions = '<div class="actions"><i style="cursor: move" class="fa fa-arrows"></i> <i style="cursor: pointer" class="fa fa-times text-danger"></i></div>'
  const callback = $field.find('.group-input-fields-content').attr('data-callback-render')
  const $sortable = panel.children('.cama_w_custom_fields')

  function AddField(value) {
    const field = $field.clone(true)
    if (fieldData.multiple) {
      field.prepend(fieldActions)
      if (fieldCounter === 0)
        field.children('.actions').find('.fa-times').remove()
    }
    if (!$field.find('.group-input-fields-content').hasClass('cama_skip_cf_rename_multiple'))
      field.find('input, textarea, select').each(function() { $(this).attr('name', $(this).attr('name').replace('[]', '[' + fieldCounter + ']')) })

    if (fieldData.disabled) {
      field.find('input, textarea, select').prop('readonly', true).filter('select').click(function() { return false }).focus(function() { $(this).blur() })
      field.find('.btn').addClass('disabled').unbind().click(function() { return false })
    }

    if (fieldData.kind === 'checkbox')
      field.find('input')[0].checked = value
    else if (value)
      field.find('.input-value').val(value).trigger('change', { field_rendered: true }).data('value', value)

    $sortable.append(field)
    if (callback)
      window[callback](field, value)
    fieldCounter++
  }

  if (fieldData.kind !== 'checkbox' && values.length <= 0)
    values = [fieldData.default_value]

  if (fieldData.kind !== 'checkboxes') {
    if (!fieldData.multiple && values.length > 1) values = [values[0]]
    if (fieldData.kind === 'checkbox')
      AddField(values[0])
    else {
      $.each(values, function(i, value) {
        AddField(value)
      })
    }
  } else AddField(values)

  if (fieldData.multiple) { // sortable actions
    panel.find('.field_multiple_btn .btn').click(function() { AddField(fieldData.default_value); return false })
    panel.delegate('.actions .fa-times', 'click', function() { if (confirm(I18n('msg.delete_item'))) $(this).closest('.editor-custom-fields').remove(); return false })
    $sortable.sortable({
      handle: '.fa-arrows',
      items: ' > .editor-custom-fields',
      start: function(e, ui) { // fix tinymce
        $(ui.item).find('.mce-panel').each(function() {
          tinymce.execCommand('mceRemoveEditor', false, $(this).next().addClass('cama_restore_editor').attr('id'))
        })
      },
      stop: function(e, ui) { // fix tinymce
        $(ui.item).find('.cama_restore_editor').each(function() {
          tinymce.execCommand('mceAddEditor', true, $(this).attr('id'))
        })
      }
    })
  }
}

// eslint-disable-next-line no-unused-vars
function CustomFieldColorpicker($field) {
  if ($field)
    $field.find('.my-colorpicker').colorpicker()
}

// eslint-disable-next-line no-unused-vars
function CustomFieldColorpickerVal($field, value) {
  if ($field)
    $field.find('.my-colorpicker').attr('data-color', value || '').colorpicker()
}

// eslint-disable-next-line no-unused-vars
function CustomFieldCheckboxVal($field, values) {
  if (values === 't') values = 1 // fix for values saved as true
  if ($field)
    $field.find('input[value="' + values + '"]').prop('checked', true)
}

// eslint-disable-next-line no-unused-vars
function CustomFieldCheckboxesVal($field, values) {
  if ($field) {
    const selector = values.map(function(value) {
      return "input[value='" + value + "']"
    }).join(',')
    $field.find(selector).prop('checked', true)
  }
}

// eslint-disable-next-line no-unused-vars
function CustomFieldDate($field) {
  if ($field) {
    const box = $field.find('.date-input-box')
    if (box.hasClass('is_datetimepicker'))
      box.datetimepicker({ format: 'YYYY-MM-DD HH:mm' })
    else
      box.datepicker()
  }
}

// eslint-disable-next-line no-unused-vars
function CustomFieldEditor($field) {
  if ($field) {
    const id = 't_' + Math.floor((Math.random() * 100000) + 1) + '_area'
    const textarea = $field.find('textarea').attr('id', id)

    if (textarea.hasClass('is_translate')) {
      textarea.addClass('translatable').Translatable(ADMIN_TRANSLATIONS)
      const inputs = textarea.data('translation_inputs')
      if (inputs) { // multiples languages
        for (const lang in inputs) {
          tinymce.init(CamaGetTinymceSettings({
            selector: '#' + inputs[lang].attr('id'),
            height: 120
          }))
        }
        return
      }
    }
    tinymce.init(CamaGetTinymceSettings({
      selector: '#' + id,
      height: 120
    }))
  }
}

// eslint-disable-next-line no-unused-vars
function CustomFieldFieldAttrsVal($field, value) {
  if ($field) {
    value = value || '{}'
    const data = typeof (value) === 'object' ? value : $.parseJSON(value)
    $field.find('.input-attr').val(data.attr)
    $field.find('.input-value').val(data.value)
    $field.find('.input-attr, .input-value').filter('.is_translate').addClass('translatable').Translatable(ADMIN_TRANSLATIONS)
  }
}

// eslint-disable-next-line no-unused-vars
function CustomFieldRadioVal($field, value) {
  if ($field) {
    $field.find('input').prop('checked', false)
    $field.find("input[value='" + value + "']").prop('checked', true)
  }
}

// eslint-disable-next-line no-unused-vars
function CustomFieldTextArea($field) {
  if ($field && $field.find('textarea').hasClass('is_translate'))
    $field.find('textarea').addClass('translatable').Translatable(ADMIN_TRANSLATIONS)
}

// eslint-disable-next-line no-unused-vars
function CustomFieldTextBox($field) {
  if ($field && $field.find('input').hasClass('is_translate'))
    $field.find('input').addClass('translatable').Translatable(ADMIN_TRANSLATIONS)
}

// eslint-disable-next-line no-unused-vars
function CustomFieldUrlCallback($field) {
  if ($field && $field.find('input').hasClass('is_translate'))
    $field.find('input').addClass('translatable').Translatable(ADMIN_TRANSLATIONS)
}

// eslint-disable-next-line no-unused-vars
function CustomFieldSelectCallback($field, val) {
  if ($field) {
    const sel = $field.find('select.input-value')
    if (!val) sel.data('value', sel.val()) // fix for select translator
    if (sel.hasClass('is_translate')) sel.addClass('translatable').Translatable(ADMIN_TRANSLATIONS)
  }
}

// eslint-disable-next-line no-unused-vars
function LoadUploadAudioField(thiss) {
  const $input = $(thiss).prev()

  $.fn.upload_filemanager({
    formats: 'audio',
    selected: function(file, response) {
      $input.val(file.url)
    }
  })
}

// eslint-disable-next-line no-unused-vars
function LoadUploadFileField(thiss) {
  const $input = $(thiss).prev()

  $.fn.upload_filemanager({
    formats: $input.data('formats') ? $input.data('formats') : '',
    selected: function(file, response) {
      $input.val(file.url)
    }
  })
}

// eslint-disable-next-line no-unused-vars
function LoadUploadPrivateFileField(thiss) {
  const $input = $(thiss).prev()

  $.fn.upload_filemanager({
    formats: $input.data('formats') ? $input.data('formats') : '',
    selected: function(file, response) {
      $input.val(file.url.split('?file=')[1].replace(/%2/g, '/'))
    },
    private: true
  })
}

// eslint-disable-next-line no-unused-vars
function LoadUploadImageField($input) {
  $.fn.upload_filemanager({
    formats: 'image',
    dimension: $input.attr('data-dimension') || '',
    versions: $input.attr('data-versions') || '',
    thumb_size: $input.attr('data-thumb_size') || '',
    selected: function(file, response) {
      $input.val(file.url).trigger('change')
    }
  })
}

// permit to show preview image of image custom fields
// eslint-disable-next-line no-unused-vars
function CamaCustomFieldImageChanged(field) {
  if (field.val()) {
    field.closest('.input-group')
      .append(
        '<span class="input-group-addon custom_field_image_preview"><a href="' +
        field.val() +
        '" target="_blank"><img src="' +
        field.val() +
        '" style="width: 50px; height: 20px;"></a></span>'
      )
  } else
    field.closest('.input-group').find('.custom_field_image_preview').remove()
}

// eslint-disable-next-line no-unused-vars
function CamaCustomFieldImageRemove(field) {
  field.val('')
  field.closest('.input-group').find('.custom_field_image_preview').remove()
}

// eslint-disable-next-line no-unused-vars
function LoadUploadVideoField(thiss) {
  const $input = $(thiss).prev()
  $.fn.upload_filemanager({
    formats: 'video',
    selected: function(file, response) {
      $input.val(file.url)
    }
  })
}
