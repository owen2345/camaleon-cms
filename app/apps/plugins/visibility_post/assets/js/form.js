/* eslint-env jquery */
jQuery(function($) {
  const panel = $('#panel-post-visibility')
  const linkEdit = panel.find('.edit-visibility').click(function() {
    panel.find('.panel-options').removeClass('hidden').show()
    linkEdit.hide()
    return false
  })

  panel.find('.lnk_hide').click(function() {
    panel.find('.panel-options').hide()
    linkEdit.show()
    return false
  })

  panel.find("input[name='post[visibility]']").change(function() {
    const label = $(this).closest('label')
    panel.find('.visibility_label').html(label.text())
    label.siblings('div').hide()
    const relBlock = label.next().show()

    if ($(this).val() === 'private')
      relBlock.find('input.visibility_private_group_item:first').addClass('required data-error-place-parent')
    else
      panel.find('input.visibility_private_group_item:first').removeClass('required')

    if ($(this).val() === 'password')
      relBlock.find('input:text').addClass('required')
    else
      panel.find('input.password_field_value').removeClass('required')
  }).filter(':checked').trigger('change')

  const calInput = $('#form-post').find('#published_from')
  calInput.datetimepicker({ format: 'YYYY-MM-DD HH:mm' })
})
