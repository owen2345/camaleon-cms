/* eslint-env jquery */
const AppPost = {}
let $form = null
/* eslint-disable-next-line no-unused-vars */
function CamaInitPost(obj) {
  $form = $('#form-post')

  /* eslint-disable-next-line eqeqeq */
  if (obj.recover_draft == 'true')
    $form.css('opacity', 0).before('<h2 style="text-align: center">' + I18n('msg.recover') + '</h2>')

  // eslint-disable-next-line no-unused-vars
  let _draftInited = false
  let classTranslate = '.translate-item'

  const postId = obj.post_id
  let postDraftId = obj.post_draft_id
  const postStatus = obj.post_status
  let _draftsPath = obj._drafts_path
  const _postsPath = obj._posts_path
  const _ajaxPath = obj._ajax_path
  const _postTagsPath = obj._post_tags_path

  AppPost.save_draft_ajax = function(callback, calledFromInterval) {
    _draftInited = true
    const data = $form.serializeObject()
    data._method = postDraftId ? 'patch' : 'post'
    data.post_id = postId
    /* eslint-disable-next-line eqeqeq */
    if ($form.data('hash') != GetHashForm() || !calledFromInterval) {
      $.ajax({
        type: 'POST',
        url: _draftsPath,
        data,
        success: function(res) {
          if (res.error)
            $.fn.alert({ type: 'error', title: res.error.join(', '), icon: 'times' })
          else {
            if (res._drafts_path) _draftsPath = res._drafts_path
            postDraftId = res.draft.id
            $('#post_draft_id').val(postDraftId)
          }
          if (callback) callback(res)
        },
        dataType: 'json',
        async: false
      })
    }
  }

  AppPost.save_draft = function() {
    AppPost.save_draft_ajax(function() {
      $form.data('submitted', 1)
      location.href = _postsPath + '?flash[notice]=' + I18n('msg.draft')
    })
  }

  if (window.post_editor_draft_intrval)
    clearInterval(window.post_editor_draft_intrval)
  window.post_editor_draft_intrval = setInterval(
    function() {
      if ($form.length === 0)
        clearInterval(window.post_editor_draft_intrval)
      else
        AppPost.save_draft_ajax(null, true)
    },
    60 * 1000
  )
  window.save_draft = AppPost.save_draft_ajax

  if ($form.find('.title-post' + classTranslate).length === 0)
    classTranslate = ''

  $form.find('.title-post' + classTranslate).each(function() {
    const $this = $(this)
    if (!$this.hasClass('sluged')) {
      if (classTranslate) {
        const lng = $this.attr('data-translation_l')
        // eslint-disable-next-line no-var
        var $inputSlug = $form.find('.slug-post' + classTranslate + '[data-translation_l="' + lng + '"]')
        // eslint-disable-next-line no-var
        var postPath = obj._post_urls[lng]
      } else {
        // eslint-disable-next-line no-redeclare, no-var
        var $inputSlug = $form.find('.slug-post')
        // eslint-disable-next-line no-redeclare, no-var
        var postPath = obj._post_urls[Object.keys(obj._post_urls)[0]]
      }

      const $link = $('<div class="sl-slug-edit">' +
        '<strong>' + I18n('msg.permalink') + ':&nbsp;</strong><span class="sl-link"></span> <span> &nbsp;&nbsp;</span>' +
        '<a href="#" class="btn btn-default btn-xs btn-edit">' + I18n('button.edit') + '</a> &nbsp;&nbsp; ' +
        '<a href="#" class="btn btn-info btn-xs btn-preview" target="_blank">' + I18n('msg.preview') + '</a> &nbsp;&nbsp; ' +
        '<a href="#" class="btn btn-success btn-xs btn-view" style="display: none" target="_blank">' + I18n('msg.view_page') + '</a>' +
        '</div>').hide()
      $this.addClass('sluged')
      $this.after($link)

      const SetSlug = slug => {
        $link.show().find('.sl-link').html(postPath.replace('__-__', '<span class="sl-url">' + slug + '</span>'))
        $link.find('.btn-preview').attr('href', postPath.replace('__-__', slug) + '?draft_id=' + postDraftId)
        $inputSlug.trigger('change_in')
        SetMetaSlug()
      }

      let xhr = null

      function AjaxSetSlug(slug) {
        if (xhr) xhr.abort()
        xhr = $.ajax({
          type: 'POST',
          url: _ajaxPath,
          data: { method: 'exist_slug', slug, postId },
          success: function(res) {
            if (res.index > 0) {
              $inputSlug.addClass('slugify-locked').val(res.slug)
              SetSlug(res.slug)
            }
          }
        })
      }

      function SetMetaSlug() {
        $('#meta_slug').val($form.find('.slug-post' + classTranslate).map(function() { return this.value }).get().join(','))
      }

      let slugTmp = null
      $inputSlug.slugify($this, {
        change: function(slug) {
          if (slug === '') {
            // generate 5-length random character slug when slugify result is empty
            slug = Math.random().toString(36).replace(/[^a-z]+/g, '').substr(0, 5)
          }
          slugTmp = slug
          SetSlug(slug)
        }
      }
      )

      $this.change(function() {
        if (slugTmp) AjaxSetSlug(slugTmp)
      })
      if ($inputSlug.val()) {
        SetSlug($inputSlug.val())
        if (postStatus === 'published')
          $link.find('.btn-view').show().attr('href', postPath.replace('__-__', $inputSlug.val()))
      }
      $link.find('.btn-preview').click(function() { // preview button
        const link = $(this)
        showLoading()
        AppPost.save_draft_ajax(function() {
          hideLoading()
          const ar = link.attr('href').split('draft_id=')
          ar[1] = postDraftId
          const clone = link.clone().hide()
          clone.insertAfter(link).attr('href', ar.join('draft_id='))[0].click()
          clone.remove()
        })
        return false
      })

      $link.find('.btn-edit').click(function() {
        const $btn = $(this)
        const $btnEdit = $(
          '<a href="#" class="btn btn-default btn-xs btn-edit">' + I18n('button.accept') + '</a> &nbsp; <a href="#" class="btn-cancel">' + I18n('button.cancel') + '</a>'
        )
        const $label = $link.find('.sl-url')
        const $input = $("<input type='text' />").keyup(
          function(e) {
            if (e.keyCode === 13)
              $btnEdit.filter('.btn-edit').click()
            return false
          }
        )
        $label.hide().after($input)
        $btn.hide().after($btnEdit)
        $input.val($label.text())

        function SetDelete() {
          $label.show()
          $btn.show()
          $input.remove()
          $btnEdit.remove()
        }

        $btnEdit.filter('.btn-cancel').click(function() {
          SetDelete()
          SetMetaSlug()
          return false
        })
        $btnEdit.filter('.btn-edit').click(function() {
          const valueNewSlug = slugFunc($input.val())
          if (valueNewSlug) {
            $inputSlug.addClass('slugify-locked').val(valueNewSlug)
            AjaxSetSlug(valueNewSlug)
            SetSlug(valueNewSlug)
            SetDelete()
          }
          return false
        })
        return false
      })
    }
  })

  try { $('.tinymce_textarea:not(.translated-item)', $form).tinymce().destroy() } catch (e) { }
  tinymce.init(CamaGetTinymceSettings({
    selector: '.tinymce_textarea:not(.translated-item)',
    height: '480px',
    base_path: obj.base_path
  }))

  $form.validate()
  const postStatusSelector = $('#post_status')
  postStatusSelector.change(function() {
    $('#post-actions .btn[data-type]').hide()
    $('#post-actions .btn[data-type="' + $(this).val() + '"]').show()
  })

  // here all later actions
  const FormLaterActions = function() {
    /** ********* scroller (fix buttons position) ***************/
    const panelScroll = $('#form-post > #post_right_bar')
    const fixedPosition = panelScroll.children(':first')
    const fixedOffsetTop = panelScroll.offset().top

    $(window).scroll(function() {
      if ($(window).width() < 1024) {
        fixedPosition.css({ position: '', width: '' })
        panelScroll.css('padding-top', '')
        return
      }
      if ($(window).scrollTop() >= fixedOffsetTop + 10) {
        fixedPosition.css({ position: 'fixed', width: panelScroll.width() + 'px', top: 0, 'z-index': 4 })
        panelScroll.css('padding-top', fixedPosition.height() + 20)
      } else {
        fixedPosition.css({ position: '', width: 'auto' })
        panelScroll.css('padding-top', '')
      }
    }).resize(function() {
      if ($(window).width() >= 1024)
        panelScroll.show()
    }).scroll()
    /** ********* end scroller buttons ***************/

    /** ******** post tagEditor ******************/
    const postTags = $.ajax({
      type: 'GET',
      url: _postTagsPath,
      dataType: 'json',
      async: false
    }).responseText

    $form.find('.tagsinput').tagEditor({
      autocomplete: { delay: 0, position: { collision: 'flip' }, source: $.parseJSON(postTags) },
      forceLowercase: false,
      placeholder: I18n('button.add_tag') + '...'
    })
    /** ******** end post tagEditor **************/
    /// /// thumbnail
    $form.on('click', '.gallery-item-remove', function() {
      $('#feature-image').hide()
      $('#feature-image input').val('')
      return false
    })

    /* Disabled until fix to reload only category fields and not all
        $form.on("change", ".list-categories input", function () {
          showLoading();
          $.get(
            $form.find("#post_add_new_category").data('fields-reload-url'), {
              categories: $form.find("#post_right_bar .list-categories input[name='categories[]']:checked").map(function(i, el){ return $(this).val(); }).get(),
              post_id: postId
            },
            function (res) {
              $form.find('.c-field-group').remove();
              $form.find('.panel .panel-default').after(res);
              hideLoading();
            });
        });
        */

    // sidebar toggle
    // $("#admin_content #post_right_bar-toggle").on("click", function () {
    //    $("#post_right_bar").is(":visible") ? $("#post_right_bar").hide() : $("#post_right_bar").show();
    // });

    /** ********* control save changes before unload form. ***************/
    $form.submit(function() {
      if ($(this).valid()) $form.data('submitted', 1)
    })
    window.onbeforeunload = function() {
      if ($form.data('submitted') || $('#form-post').length === 0)
        return
      if ($form.data('hash') !== GetHashForm())
        return 'You sure to leave the page without saving changes?'

      if (!$form.data('submitted'))
        return
      return 'You sure to leave the page without saving changes?'
    }

    /** ********* link to create categories *************/
    $form.find('#post_add_new_category').ajax_modal({
      modal_size: 'modal-lg',
      mode: 'iframe',
      callback: function(modal) {
        modal.find('iframe').on('load', function() {
          $(this).contents().find('#main-header, #sidebar-menu, #main-footer').hide()
          $(this).contents().find('#admin_content').parent().css('margin-left', 0)
        })
      },
      on_close: function(modal) {
        const panelCats = $form.find('#post_right_bar .list-categories')
        $.get(
          $form.find('#post_add_new_category').data('reload-url'),
          { categories: panelCats.find("input[name='categories[]']:checked").map(function(i, el) { return $(this).val() }).get() },
          function(res) { panelCats.html(res) }
        )
      }
    })
    /** ********* end *************/
  }
  setTimeout(FormLaterActions, 1000)
  setTimeout(function() { $form.data('hash', GetHashForm()) }, 2000)

  function GetHashForm() {
    tinymce.editors.forEach(function(editor) {
      $('#' + editor.id).val(tinymce.get(editor.id).getContent()).trigger('change')
    })

    return $form.serialize()
  }

  /* eslint-disable-next-line eqeqeq */
  if (obj.recover_draft == 'true') {
    $form.data('validator').cancelSubmit = true
    postStatusSelector.val('published')
    $form.submit()
  }
}

// thumbnail uploader
// eslint-disable-next-line no-unused-vars
function CamaUploadFeatureImage(data) {
  $.fn.upload_filemanager($.extend({
    formats: 'image',
    selected: function(image) {
      const imageUrl = image.url
      $('#feature-image img').attr('src', imageUrl)
      $('#feature-image input').val(imageUrl)
      $('#feature-image .meta strong').html(image.name)
      $('#feature-image').show()
    }
  }, data))
}
