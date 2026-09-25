var App_post = {};
var $form = null;
function cama_init_post(obj) {
    $form = $('#form-post');

    if (obj.recover_draft == "true") {
        $form.css('opacity', 0).before('<h2 style="text-align: center">' + I18n("msg.recover") + '</h2>');
    }

    var class_translate = ".translate-item";

    var post_id = obj.post_id;
    var post_draft_id = obj.post_draft_id;
    var post_status = obj.post_status;
    var _drafts_path = obj._drafts_path;
    var _posts_path = obj._posts_path;
    var _ajax_path = obj._ajax_path;
    var _post_tags_path = obj._post_tags_path;

    // The form's state is compared by its serialization (get_hash_form). The baseline, data("hash"), which
    // the leave-page prompt reads too, is taken once the editors are ready; saved_hash is the state the
    // last successful draft save sent, so the minute timer sends only what changed since. One save runs
    // at a time: a save requested meanwhile waits for the draft id the running one returns, so a new
    // post never gets a second buffer, and a form submitted meanwhile is sent once the draft id is in it,
    // or after App_post.submit_wait_ms if the save has not returned by then; a refused save leaves it on the
    // form. A save that has not returned after App_post.save_timeout_ms fails.
    var saved_hash = null;
    var saving = false;
    var queued_saves = [];
    var submit_after_save = false;
    var submit_wait_timer = null;
    var submit_without_waiting = false;
    App_post.submit_wait_ms = 15000;
    App_post.save_timeout_ms = 30000;

    // on_failure runs when the save is refused or the request fails.
    App_post.save_draft_ajax = function (callback, called_from_interval, on_failure) {
        if (saving) {
            queued_saves.push([callback, called_from_interval, on_failure]);
            return;
        }
        var hash = get_hash_form();
        if (called_from_interval && (saved_hash === null || hash == saved_hash)) return;

        var data = $form.serializeObject();
        data._method = post_draft_id ? 'patch' : 'post';
        data.post_id = post_id;
        saving = true;
        $.ajax({
            type: 'POST',
            url: _drafts_path,
            data: data,
            // jQuery skips `complete` when a success handler throws, so each handler releases the lock itself.
            success: function (res) {
                try {
                    if (res.error) {
                        // Render the messages as text ($.fn.alert feeds its title into an HTML sink and a
                        // refusal names the submitted key), and do NOT run the success callback -- it would
                        // navigate away (discarding the unsaved edits) or open a stale preview.
                        $.fn.alert({type: 'error', title: $('<div>').text(res.error.join(", ")).html(), icon: "times"})
                        release_held_submit();
                        if (on_failure) on_failure();
                    } else {
                        if (res._drafts_path) _drafts_path = res._drafts_path
                        post_draft_id = res.draft.id
                        saved_hash = hash;
                        $("#post_draft_id").val(post_draft_id);
                        set_preview_draft_id();
                        if (callback) callback(res);
                    }
                } finally {
                    save_finished();
                }
            },
            error: function () {
                try {
                    if (on_failure) on_failure();
                } finally {
                    save_finished();
                }
            },
            dataType: 'json',
            // A save that has not returned after this long is taken as failed, so a stalled request
            // does not keep the editor from saving or previewing until the browser gives up on it.
            timeout: App_post.save_timeout_ms
        });
    };

    function save_finished() {
        saving = false;
        // A queued timer call with nothing to send returns without saving, so go on to the next.
        while (!saving && queued_saves.length) App_post.save_draft_ajax.apply(null, queued_saves.shift());
        if (!saving && submit_after_save) send_held_submit();
    }

    function send_held_submit() {
        submit_after_save = false;
        clearTimeout(submit_wait_timer);
        $form.submit();
    }

    // A refused save leaves a held submit on the form: the post save would refuse the same content, and
    // the alert names what to fix. A request that failed or timed out still sends it (see the submit handler).
    function release_held_submit() {
        if (!submit_after_save) return;
        submit_after_save = false;
        clearTimeout(submit_wait_timer);
        hideLoading();
    }

    function set_preview_draft_id() {
        $form.find('.sl-slug-edit .btn-preview').each(function () {
            $(this).attr('href', $(this).attr('href').replace(/draft_id=[^&]*/, 'draft_id=' + post_draft_id));
        });
    }

    // The overlay holds the form while the save runs: the callback leaves the page with the form marked
    // submitted, so an edit made meanwhile would be lost without the leave prompt.
    App_post.save_draft = function () {
        showLoading();
        App_post.save_draft_ajax(function () {
            $form.data("submitted", 1);
            location.href = _posts_path + '?flash[notice]=' + I18n("msg.draft")
        }, false, hideLoading);
    }
    if(window["post_editor_draft_intrval"]) clearInterval(window["post_editor_draft_intrval"]);
    window["post_editor_draft_intrval"] = setInterval(function () { if($form.length == 0){ clearInterval(window["post_editor_draft_intrval"]); } else{ App_post.save_draft_ajax(null, true); } }, 1 * 60 * 1000);
    window.save_draft = App_post.save_draft_ajax;

    if($form.find(".title-post" + class_translate).length == 0) class_translate = '';
    $form.find(".title-post" + class_translate).each(function () {
        var $this = $(this);
        if (!$this.hasClass('sluged')) {
            if (class_translate) {
                var lng = $this.attr("data-translation_l");
                var $input_slug = $form.find('.slug-post' + class_translate + '[data-translation_l="' + lng + '"]');
                var post_path = obj._post_urls[lng];
            } else {
                var $input_slug = $form.find('.slug-post');
                var post_path = obj._post_urls[Object.keys(obj._post_urls)[0]];
            }

            var $link = $('<div class="sl-slug-edit">' +
                '<strong>' + I18n("msg.permalink") + ':&nbsp;</strong><span class="sl-link"></span> <span> &nbsp;&nbsp;</span>' +
                '<a href="#" class="btn btn-default btn-xs btn-edit">' + I18n("button.edit") + '</a> &nbsp;&nbsp; ' +
                '<a href="#" class="btn btn-info btn-xs btn-preview" target="_blank">' + I18n("msg.preview") + '</a> &nbsp;&nbsp; ' +
                '<a href="#" class="btn btn-success btn-xs btn-view" style="display: none" target="_blank">' + I18n("msg.view_page") + '</a>' +
                '</div>').hide();
            $this.addClass('sluged');
            $this.after($link)

            function set_slug(slug) {
                $link.show().find('.sl-link').html(post_path.replace('__-__', '<span class="sl-url">' + slug + '</span>'))
                $link.find('.btn-preview').attr('href', post_path.replace('__-__', slug) + '?draft_id=' + post_draft_id)
                $input_slug.trigger('change_in');
                set_meta_slug();
            }

            var xhr = null;

            function ajax_set_slug(slug) {
                if (xhr) xhr.abort();
                xhr = $.ajax({
                    type: "POST",
                    url: _ajax_path,
                    data: {method: 'exist_slug', slug: slug, post_id: post_id},
                    success: function (res) {
                        if (res.index > 0) {
                            $input_slug.addClass('slugify-locked').val(res.slug);
                            set_slug(res.slug)
                        }

                    }
                });
            }

            function set_meta_slug() {
                $('#meta_slug').val($form.find('.slug-post' + class_translate).map(function () { return this.value; }).get().join(","));
            }

            var slug_tmp = null;
            $input_slug.slugify($this, {
                    change: function (slug) {
                        if (slug == "") {
                            // generate 5-length random character slug when slugify result is empty
                            slug = Math.random().toString(36).replace(/[^a-z]+/g, '').substr(0, 5);
                        }
                        slug_tmp = slug;
                        set_slug(slug);
                    }
                }
            );

            $this.change(function () {
                if (slug_tmp) ajax_set_slug(slug_tmp);
            });
            if ($input_slug.val()) {
                set_slug($input_slug.val());
                if (post_status == "published") $link.find('.btn-view').show().attr('href', post_path.replace('__-__', $input_slug.val()))
            }
            $link.find('.btn-preview').click(function () { // preview button
                var link = $(this);
                // Open the window within the click: a popup blocker refuses one opened from the save's
                // asynchronous callback. The save points the link at the draft before the callback runs.
                var preview = window.open('', '_blank');
                if (preview) preview.opener = null;
                showLoading();
                App_post.save_draft_ajax(function(){
                    hideLoading();
                    if (preview) preview.location.href = link.prop('href');
                    else window.open(link.prop('href'), '_blank');
                }, false, function(){
                    hideLoading();
                    if (preview) preview.close();
                });
                return false;
            });
            $link.find('.btn-edit').click(function () {
                var $btn = $(this);
                var $btn_edit = $('<a href="#" class="btn btn-default btn-xs btn-edit">' + I18n("button.accept") + '</a> &nbsp; <a href="#"  class="btn-cancel">' + I18n("button.cancel") + '</a>');
                var $label = $link.find('.sl-url');
                var $input = $("<input type='text' />").keyup(function(e){ if(e.keyCode == 13){ $btn_edit.filter('.btn-edit').click(); return false; } });
                $label.hide().after($input);
                $btn.hide().after($btn_edit);
                $input.val($label.text());

                function set_delete() {
                    $label.show();
                    $btn.show();
                    $input.remove();
                    $btn_edit.remove();
                }

                $btn_edit.filter('.btn-cancel').click(function () {
                    set_delete();
                    set_meta_slug()
                    return false;
                });
                $btn_edit.filter('.btn-edit').click(function () {
                    var value_new_slug = slugFunc($input.val());
                    if (value_new_slug) {
                        $input_slug.addClass('slugify-locked').val(value_new_slug);
                        ajax_set_slug(value_new_slug)
                        set_slug(value_new_slug)
                        set_delete();
                    }
                    return false;
                });
                return false;
            });
        }
    });

    try{$(".tinymce_textarea:not(.translated-item)", $form).tinymce().destroy();}catch(e){}
    tinymce.init(cama_get_tinymce_settings({
        selector: '.tinymce_textarea:not(.translated-item)',
        height: '480px',
        base_path: obj.base_path
    }));

    $form.validate();
    $("#post_status").change(function () {
        $('#post-actions .btn[data-type]').hide();
        $('#post-actions .btn[data-type="' + $(this).val() + '"]').show();
    });

    // here all later actions
    var form_later_actions = function () {
        /*********** scroller (fix buttons position) ***************/
        var panel_scroll = $("#form-post > #post_right_bar");
        var fixed_position = panel_scroll.children(":first");
        var fixed_offset_top = panel_scroll.offset().top;
        $(window).scroll(function () {
            if ($(window).width() < 1024) {
                fixed_position.css({position: "", width: ""});
                panel_scroll.css("padding-top", "");
                return;
            }
            if ($(window).scrollTop() >= fixed_offset_top + 10) {
                fixed_position.css({position: "fixed", width: panel_scroll.width()+'px', top: 0, "z-index": 4});
                panel_scroll.css("padding-top", fixed_position.height() + 20)
            } else {
                fixed_position.css({position: "", width: "auto"});
                panel_scroll.css("padding-top", "")
            }
        }).resize(function () {
            if ($(window).width() >= 1024) {
                panel_scroll.show();
            }
        }).scroll();
        /*********** end scroller buttons ***************/

        /********** post tagEditor ******************/
        var post_tags = $.ajax({
            type: 'GET',
            url: _post_tags_path,
            dataType: "json",
            async: false
        }).responseText;

        $form.find(".tagsinput").tagEditor({
            autocomplete: {delay: 0, position: {collision: 'flip'}, source: $.parseJSON(post_tags)},
            forceLowercase: false,
            placeholder: I18n("button.add_tag") + '...'
        });
        /********** end post tagEditor **************/
            ////// thumbnail
        $form.on("click", ".gallery-item-remove", function () {
            $('#feature-image').hide();
            $('#feature-image input').val('');
            return false;
        });

        /* Disabled until fix to reload only category fields and not all.
           NOTE (M6): custom_fields#list performs its category write only on a CSRF-verified POST, so
           this must stay $.post when re-enabled (jquery_ujs attaches the CSRF token) — with $.get the
           fields would still render but the post's categories would silently not be saved.
        $form.on("change", ".list-categories input", function () {
          showLoading();
          $.post(
            $form.find("#post_add_new_category").data('fields-reload-url'), {
              categories: $form.find("#post_right_bar .list-categories input[name='categories[]']:checked").map(function(i, el){ return $(this).val(); }).get(),
              post_id: post_id
            },
            function (res) {
              $form.find('.c-field-group').remove();
              $form.find('.panel .panel-default').after(res);
              hideLoading();
            });
        });
        */

        // sidebar toggle
        //$("#admin_content #post_right_bar-toggle").on("click", function () {
        //    $("#post_right_bar").is(":visible") ? $("#post_right_bar").hide() : $("#post_right_bar").show();
        //});

        /*********** control save changes before unload form. ***************/
        $form.submit(function () {
            if (!$(this).valid()) return;
            if (saving && !submit_without_waiting) {
                if (!submit_after_save) {
                    submit_after_save = true;
                    showLoading();
                    // A stalled save must not keep the post from being saved: on a new post this may
                    // leave that save's buffer behind, which is the lesser loss.
                    submit_wait_timer = setTimeout(function () {
                        submit_without_waiting = true;
                        send_held_submit();
                    }, App_post.submit_wait_ms);
                }
                return false;
            }
            $form.data("submitted", 1);
        });
        window.onbeforeunload = function () {
            if ($form.data("submitted") || $('#form-post').length == 0)
                return;
            if ($form.data("hash") != get_hash_form()) {
                return "You sure to leave the page without saving changes?";
            }
            if (!$form.data("submitted"))
                return;
            return "You sure to leave the page without saving changes?";
        };

        /*********** link to create categories *************/
        $form.find("#post_add_new_category").ajax_modal({modal_size: 'modal-lg', mode: 'iframe', callback: function(modal){
            modal.find('iframe').on('load', function(){
                $(this).contents().find("#main-header, #sidebar-menu, #main-footer").hide();
                $(this).contents().find('#admin_content').parent().css("margin-left", 0);
            });
        }, on_close: function(modal){
            var panel_cats = $form.find("#post_right_bar .list-categories");
            $.get($form.find("#post_add_new_category").data('reload-url'), {categories: panel_cats.find("input[name='categories[]']:checked").map(function(i, el){ return $(this).val(); }).get()}, function(res){ panel_cats.html(res); });
        }});
        /*********** end *************/
    }
    setTimeout(form_later_actions, 1000);
    // On its own timer, so a failure in form_later_actions does not leave the form without a baseline.
    setTimeout(take_baseline_when_ready, 1000);

    // An editor rewrites its textarea in normalized form once it comes up, so a baseline taken before
    // every editor on the form has initialized reads an untouched post as edited. Each editor's init
    // event re-checks; stop waiting after ten seconds (an editor that never comes up) and take the form
    // as it stands.
    function take_baseline_when_ready() {
        var taken = false;
        var give_up = setTimeout(take_baseline, 10000);
        function take_baseline() {
            if (taken) return;
            taken = true;
            clearTimeout(give_up);
            tinymce.off('AddEditor', watch_editor);
            var hash = get_hash_form();
            // A draft save that ran meanwhile already recorded what it sent; later edits are still unsaved.
            if (saved_hash === null) saved_hash = hash;
            $form.data("hash", hash);
        }
        function check() { if (!taken && editors_ready()) take_baseline(); }
        function watch_editor(e) { e.editor.on('init', check); }
        tinymce.on('AddEditor', watch_editor);
        $.each(tinymce.editors, function (i, editor) { if (!editor.initialized) editor.on('init', check); });
        check();
    }

    function editors_ready() {
        var ready = true;
        $form.find('.tinymce_textarea:not(.translated-item)').each(function () {
            var editor = tinymce.get(this.id);
            if (!editor || !editor.initialized) ready = false;
        });
        $.each(tinymce.editors, function (i, editor) {
            if (!editor.initialized && $.contains($form[0], editor.getElement())) ready = false;
        });
        return ready;
    }

    // The draft id is left out: a save filling it in is not an edit.
    function get_hash_form() {
        // $.each walks the indexes only: TinyMCE keys the array by editor id too, so for..in visits each twice.
        $.each(tinymce.editors, function (i, editor) {
            if (!editor.initialized) return; // still loading, its textarea holds the server value
            $("#" + editor.id).val(editor.getContent()).trigger("change");
        });
        return $form.find(':input').not('#post_draft_id').serialize();
    }

    if (obj.recover_draft == "true") {
        $form.data("validator").cancelSubmit = true;
        $('#post_status').val('published');
        $form.submit();
    }
}

// thumbnail uploader
function cama_upload_feature_image(data) {
    $.fn.upload_filemanager($.extend({
        formats: "image",
        selected: function (image) {
            var image_url = image.url;
            $('#feature-image img').attr('src', image_url);
            $('#feature-image input').val(image_url);
            $('#feature-image .meta strong').html(image.name);
            $('#feature-image').show();
        }
    }, data));
}
