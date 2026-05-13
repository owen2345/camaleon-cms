jQuery(function($){
  var $restartModal = $("#server-restart-modal")
  if (!$restartModal.length) return

  var pendingAction = null

  // Link-based actions (e.g., activate/deactivate plugin, select theme)
  $(document).on("click", "[data-restart-confirm]", function(e){
    e.preventDefault()
    e.stopImmediatePropagation()
    var $el = $(this)
    var deleteUrl = $el.data("delete-url")
    if (deleteUrl) {
      pendingAction = { type: "delete", url: deleteUrl }
    } else {
      pendingAction = { type: "link", url: $el.attr("href") }
    }
    $restartModal.modal("show")
  })

  // Form-based actions (e.g., submit languages, create/edit post type, create/edit site)
  $(document).on("click", "[data-restart-submit]", function(e){
    e.preventDefault()
    pendingAction = { type: "form", form: $(this).closest("form") }
    $restartModal.modal("show")
  })

  // Confirm button inside modal
  $restartModal.find("[data-role='restart-confirm']").on("click", function(e){
    e.preventDefault()
    if (pendingAction) {
      if (pendingAction.type === "form") {
        pendingAction.form.submit()
      } else if (pendingAction.type === "delete") {
        var $form = $('<form>', { method: 'post', action: pendingAction.url })
        $form.append($('<input>', { type: 'hidden', name: '_method', value: 'delete' }))
        $form.append($('<input>', { type: 'hidden', name: 'authenticity_token', value: $('meta[name="csrf-token"]').attr('content') }))
        $form.appendTo('body').submit()
      } else {
        window.location.href = pendingAction.url
      }
    }
    $restartModal.modal("hide")
  })

  // ESC key closes modal
  $(document).on("keydown", function(event){
    if (event.which === 27 && $restartModal.hasClass("in")) {
      $restartModal.modal("hide")
    }
  })

  // Reset pending action on modal close
  $restartModal.on("hidden.bs.modal", function(){
    pendingAction = null
  })
})
