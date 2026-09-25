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
    // post never gets a second buffer, and a form submitted meanwhile is held, then submitted again once
    // the draft id is in it, or after App_post.submit_wait_ms if the save has not returned by then; a
    // refused save leaves it on the form. A save that has not returned after App_post.save_timeout_ms fails.
    var saved_hash = null;
    var saving = false;
    var queued_saves = [];
    var submit_wait_timer = null;
    var held_form = null;
    var releasing_form = null;
    // The form this setup owns. Admin pages load in place, so the script can be set up on another form
    // while a save of this one is queued or in flight; $form is then that form, and this setup's saves are
    // not for it.
    var post_form = $form[0];
    // Defaults, kept when a plugin or theme set them (zero included) before the editor came up.
    if (App_post.submit_wait_ms == null) App_post.submit_wait_ms = 15000;
    if (App_post.save_timeout_ms == null) App_post.save_timeout_ms = 30000;

    // on_failure runs when the save is refused, the request fails or it could not be sent.
    App_post.save_draft_ajax = save_draft_ajax;
    function save_draft_ajax(callback, called_from_interval, on_failure) {
        if (saving) {
            queued_saves.push([callback, called_from_interval, on_failure]);
            return;
        }
        // Drained from the queue after the page loaded another form in place: $form is that form now, and
        // serializing it would send the other post's content to this post's draft. The caller's failure
        // handler takes down what it opened (a Preview window, the overlay).
        if ($form[0] !== post_form) {
            if (on_failure) on_failure();
            return;
        }
        if (called_from_interval && (saved_hash === null || get_hash_form() == saved_hash)) return;

        // The form the save is sent for: with pages loading in place, the response may find the editor set
        // up on another form, whose draft id and Preview links are its own.
        var form = $form[0];
        // Locked before the editors are synced: a change handler that asks for a save is queued behind
        // this one, not sent beside it.
        saving = true;
        try {
            sync_editors();
            // Read after the sync: the textareas' change handlers may have written other fields, and saved_hash is the form as sent.
            var hash = get_hash_form();
            var data = $form.serializeObject();
            data._method = post_draft_id ? 'patch' : 'post';
            data.post_id = post_id;
            $.ajax(draft_request(data, hash, form, callback, called_from_interval, on_failure));
        } catch (e) {
            // The save threw before it was sent (a change handler, a plugin's $.ajax wrapper, a prefilter):
            // nothing will release the lock, and the caller's failure handler is the only way its overlay
            // or window is taken down.
            try { if (on_failure) on_failure(); } finally { save_finished(); }
            throw e;
        }
    }

    function draft_request(data, hash, form, callback, called_from_interval, on_failure) {
        return {
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
                        // A refused save leaves a held submit on the form (the alert took the overlay down): the
                        // post save would refuse the same content, and the alert names what to fix. A request that
                        // failed or timed out still sends it (see the submit handler). The held submit is not
                        // dispatched again, so a cancelSubmit the validator's click handler set for it (a Cancel or
                        // formnovalidate button) is consumed here, as its own submit handler would have: left set,
                        // it would let the next submit through unvalidated.
                        var validator = held_form && $(held_form).data('validator');
                        if (validator) validator.cancelSubmit = false;
                        drop_hold();
                        // A timer call queued behind this save would send the same form again, to the same
                        // refusal; the next tick retries. A user's call stays queued: it recomputes the form.
                        queued_saves = $.grep(queued_saves, function (queued) { return !queued[1]; });
                        if (on_failure) on_failure();
                    } else {
                        if (res._drafts_path) _drafts_path = res._drafts_path
                        post_draft_id = res.draft.id
                        saved_hash = hash;
                        $(form).find("#post_draft_id").val(post_draft_id);
                        set_preview_draft_id(form);
                        if (callback) callback(res);
                    }
                } finally {
                    save_finished();
                }
            },
            error: function () {
                try {
                    // A save the user asked for says it failed; the timer's is retried a minute later, and a
                    // held submit is sent right after this (the post save reports for itself).
                    if (!called_from_interval && !held_form) {
                        $.fn.alert({type: 'error', title: I18n("msg.draft_save_failed", "The draft could not be saved"), icon: "times"});
                    }
                    if (on_failure) on_failure();
                } finally {
                    save_finished();
                }
            },
            dataType: 'json',
            // A save that has not returned after this long is taken as failed, so a stalled request
            // does not keep the editor from saving or previewing until the browser gives up on it.
            timeout: App_post.save_timeout_ms
        };
    }

    function save_finished() {
        saving = false;
        // A queued timer call with nothing to send returns without saving, so go on to the next. Each is
        // run from here, not through App_post.save_draft_ajax: a wrapper a plugin put there already ran
        // when the call was made.
        while (!saving && queued_saves.length) save_draft_ajax.apply(null, queued_saves.shift());
        if (!held_form) return;
        // A hold that goes on waiting, for the queued save just started, needs the overlay put back: the
        // finished save's caller (Preview, Save Draft) takes it down in its callback.
        if (saving) showLoading(); else send_held_submit();
    }

    // The held submit was stopped before validation or any other listener saw it (see the submit handler),
    // so it is dispatched again in full: validation, every listener, those delegated from an ancestor
    // included (camaleon_admin_ajax submits the form in place from one), and the form's default action
    // run once, now. The overlay comes down first: whatever the submit does from here, it does on its own.
    // It is sent to the form it was held on: with pages loading in place, another form can be set up
    // while the hold waits (the browser's Back button is not under the overlay), and one that left the
    // page is not sent at all.
    function send_held_submit() {
        var form = held_form;
        drop_hold();
        if (!form || !$.contains(document, form)) return;
        hideLoading();
        releasing_form = form;
        try { $(form).trigger('submit'); } finally { releasing_form = null; }
    }

    function drop_hold() {
        held_form = null;
        clearTimeout(submit_wait_timer);
    }

    function set_preview_draft_id(form) {
        $(form).find('.sl-slug-edit .btn-preview').each(function () {
            $(this).attr('href', $(this).attr('href').replace(/draft_id=[^&]*/, 'draft_id=' + post_draft_id));
        });
    }

    // The overlay holds the form while the save runs: the callback leaves the page with the form marked
    // submitted, so an edit made meanwhile would be lost without the leave prompt.
    App_post.save_draft = function () {
        showLoading();
        App_post.save_draft_ajax(function () {
            // The page loaded another form in place while the save ran (the browser's Back button is not
            // under the overlay): the draft is saved, and that form keeps its own leave prompt and page.
            if ($form[0] !== post_form) { hideLoading(); return; }
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
            $link.find('.btn-preview').click(function (e) { // preview button
                // Prevented first: a save that throws before sending skips the return below, and the link,
                // which names no draft yet, would open in a tab of its own.
                e.preventDefault();
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

    /*********** control save changes before unload form. ***************/
    // Bound before the validator's handler, so a submit held here is stopped before validation or any
    // other listener sees it, and each of them runs once, when the held submit is dispatched again.
    $form.submit(function (e) {
        // A submit the validator was told to let through (cancelSubmit: a Cancel or formnovalidate
        // button, the recover-draft path below) is let through here too, not validated on its way.
        var validator = $(this).data('validator');
        if (!(validator && validator.cancelSubmit) && !$(this).valid()) return;
        if (saving && releasing_form !== this) {
            if (!held_form) {
                held_form = this;
                showLoading();
                // A stalled save must not keep the post from being saved: on a new post this may
                // leave that save's buffer behind, which is the lesser loss.
                submit_wait_timer = setTimeout(send_held_submit, App_post.submit_wait_ms);
            }
            e.preventDefault();
            e.stopImmediatePropagation();
            return;
        }
        $(this).data("submitted", 1);
    });

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

        /*********** leave-page prompt (the submit handler is bound with the validator, above) ***************/
        window.onbeforeunload = function () {
            if ($form.data("submitted") || $('#form-post').length == 0)
                return;
            if ($form.data("hash") != get_hash_form()) {
                return "You sure to leave the page without saving changes?";
            }
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
    setTimeout(function () { take_baseline_when_ready(post_form); }, 1000);

    // An editor rewrites its textarea in normalized form once it comes up, so a baseline taken before
    // every editor on the form has initialized reads an untouched post as edited. Each editor's init
    // event re-checks; stop waiting after ten seconds (an editor that never comes up) and take the form
    // as it stands.
    function take_baseline_when_ready(form) {
        var taken = false;
        var give_up = setTimeout(take_baseline, 10000);
        function take_baseline() {
            if (taken) return;
            taken = true;
            clearTimeout(give_up);
            tinymce.off('AddEditor', watch_editor);
            // The editor was set up on another form meanwhile (admin pages load in place, and the form
            // read here is the one the script was last set up on): that form takes its own baseline.
            if ($form[0] !== form) return;
            var hash = get_hash_form();
            // A draft save that ran meanwhile already recorded what it sent; later edits are still unsaved.
            if (saved_hash === null) saved_hash = hash;
            $form.data("hash", hash);
        }
        function check() { if (!taken && ($form[0] !== form || editors_ready())) take_baseline(); }
        function watch_editor(e) { e.editor.on('init', check); }
        tinymce.on('AddEditor', watch_editor);
        $.each(tinymce.editors, function (i, editor) { if (!editor.initialized) editor.on('init', check); });
        check();
    }

    function editors_ready() {
        var ready = true;
        // A textarea the editor has not been created for yet; one created but still loading is caught below.
        $form.find('.tinymce_textarea:not(.translated-item)').each(function () {
            if (!tinymce.get(this.id)) ready = false;
        });
        $.each(tinymce.editors, function (i, editor) {
            if (!editor.initialized && in_form(editor)) ready = false;
        });
        return ready;
    }

    // Only the form's editors are the post's content: one a plugin puts elsewhere on the page (a modal)
    // is neither compared nor sent.
    function in_form(editor) {
        return $form.length > 0 && $.contains($form[0], editor.getElement());
    }

    // A read: each editor's content is taken from the editor and its textarea is left alone, so what a
    // plugin wrote into a textarea itself is not rewritten in TinyMCE's serialization by a comparison.
    // Left out: the draft id (a save filling it in is not an edit) and the hidden original of a
    // translated field, composed from the per-language copies that are read.
    function get_hash_form() {
        var editors = {};
        // $.each walks the indexes only: TinyMCE keys the array by editor id too, so for..in visits each twice.
        $.each(tinymce.editors, function (i, editor) {
            if (editor.initialized && in_form(editor)) editors[editor.id] = editor.getContent(); // still loading: its textarea holds the server value
        });
        // An own-property check: `in` would also match an id every object inherits, like `constructor`.
        var fields = $form.find(':input').not('#post_draft_id, .translated-item').filter(function () {
            return !Object.prototype.hasOwnProperty.call(editors, this.id);
        });
        return fields.serialize() + '&' + $.param(editors);
    }

    // Before the form is serialized for a save: each editor's content goes into its textarea, and
    // through the textarea's change handlers into the hidden original of a translated field.
    function sync_editors() {
        $.each(tinymce.editors, function (i, editor) {
            if (!editor.initialized || !in_form(editor)) return;
            $("#" + editor.id).val(editor.getContent()).trigger("change");
        });
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
