/* eslint-env jquery */
/* eslint-disable-next-line no-unused-vars */
function initProfileForm() {
  const form = $('#user_form')
  form.validate()

  $('#profie-form-ajax-password').validate({ // change password
    submitHandler: function() {
      showLoading()
      const form2 = $(this.currentForm)
      $.post(form2.attr('action'), form2.serialize(), function(res) {
        form2.flash_message(res)
      }).complete(function() {
        hideLoading()
      })
      return false
    }
  })

  form.find('.btn_change_photo').click(function() {
    $.fn.upload_filemanager({
      formats: 'image',
      selected: function(file) {
        form.find('#user_meta_avatar').val(file.url)
        form.find('img.img-thumbnail').attr('src', file.url)
      }
    })
    return false
  })
}
