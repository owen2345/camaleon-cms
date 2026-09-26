var App_post = {};
var $form = null;
function cama_init_post(obj) {
    $form = $('#form-post');

    if (obj.recover_draft == "true") {
        $form.css('opacity', 0).before('<h2 style="text-align: center">' + I18n("msg.recover") + '</h2>');
    }

    var class_translate = ".translate-item";
    // The form's editors: the textareas TinyMCE is set up on, and the ones the baseline waits for.
    var editor_selector = '.tinymce_textarea:not(.translated-item)';

    var post_id = obj.post_id;
    var post_draft_id = obj.post_draft_id;
    var post_status = obj.post_status;
    var _drafts_path = obj._drafts_path;
    var _posts_path = obj._posts_path;
    var _ajax_path = obj._ajax_path;
    var _post_tags_path = obj._post_tags_path;

    // The form's state is compared by its serialization (get_hash_form). The baseline, data("hash"), which
    // the leave-page prompt reads too, is taken once the editors are ready; saved_hash is the state the
    // last successful draft save sent and refused_hash the state the last refused one sent, so the minute
    // timer sends only what changed since either (a refusal is decided by the content it names). One save runs
    // at a time: a save requested meanwhile waits for the draft id the running one returns, so a new
    // post never gets a second buffer, and a form submitted meanwhile is held, then submitted again once
    // the draft id is in it, or after App_post.submit_wait_ms if the save has not returned by then; a
    // refused save leaves it on the form. A save that has not returned after App_post.save_timeout_ms fails.
    var saved_hash = null;
    var refused_hash = null;
    // Set by the user's own input in the form (a native input or change event: a value a script writes,
    // or jQuery's trigger, fires none), read while the baseline is still to come.
    var touched = false;
    // The baseline was taken after the user had edited the form (typed in it, or in one of its editors):
    // it absorbed the edit, so the form stays edited until it is submitted.
    var edited_before_baseline = false;
    var saving = false;
    var queued_saves = [];
    var submit_wait_timer = null;
    var held_form = null;
    var held_submitter = null;
    var releasing_form = null;
    // Set when the fallback wait sent the held submit while the save still ran: the post save reports
    // for itself from then on, so this save's failure is not reported too, its success runs the
    // caller's failure handler in place of its callback, and the saves queued behind it are dropped.
    var submit_sent_while_saving = false;
    // The form this setup owns. Admin pages load in place, so the script can be set up on another form
    // while a save of this one is queued or in flight; $form is then that form, and this setup's saves are
    // not for it.
    var post_form = $form[0];
    post_form.addEventListener('input', mark_touched);
    post_form.addEventListener('change', mark_touched);
    function mark_touched() { touched = true; }
    // An edit in an editor fires no event on the form (the editor's document is its iframe's): the
    // editor's own change event records it, fired for what adds to its undo levels (typing, pasting,
    // formatting) and not by a script's setContent. Its dirty flag would not do: TinyMCE clears it
    // whenever the editor's content is saved into its textarea, which the blur handler does.
    function mark_editor_touched(e) { if ($.contains(post_form, e.target.getElement())) touched = true; }
    function watch_editor_touch(e) { e.editor.on('change', mark_editor_touched); }
    tinymce.on('AddEditor', watch_editor_touch);
    $.each(tinymce.editors, function (i, editor) { editor.on('change', mark_editor_touched); });
    // Defaults, kept when a plugin or theme set them (zero included) before the editor came up.
    if (App_post.submit_wait_ms == null) App_post.submit_wait_ms = 15000;
    if (App_post.save_timeout_ms == null) App_post.save_timeout_ms = 30000;

    // on_failure runs when the save is refused, the request fails or it could not be sent.
    App_post.save_draft_ajax = save_draft_ajax;
    function save_draft_ajax(callback, called_from_interval, on_failure) {
        // Called, or drained from the queue, after the page loaded another form in place: $form is that
        // form now, and serializing it would send the other post's content to this post's draft. Dropped
        // before it can queue, so the caller's failure handler, which takes down what it opened (a Preview
        // window, the overlay), does not wait for a running save that is not its own.
        if ($form[0] !== post_form) {
            if (on_failure) on_failure();
            return;
        }
        if (saving) {
            // One timer call waits at a time: drained, it compares the form once, and another would compare
            // the same form again (on a request that never returns, one more every minute).
            if (called_from_interval && $.grep(queued_saves, function (queued) { return queued.from_timer; }).length) return;
            queued_saves.push({callback: callback, from_timer: called_from_interval, on_failure: on_failure});
            return;
        }
        if (called_from_interval) {
            // Nothing before the baseline, and nothing once the form is submitted: the post save removes
            // the drafts, and a save sent while its response is still to come would write a buffer after
            // that, offered for recovery on the next edit.
            if (saved_hash === null || $form.data("submitted")) return;
            var current = get_hash_form();
            if (current == saved_hash || current == refused_hash) return;
        }

        // Locked before the editors are synced: a change handler that asks for a save is queued behind
        // this one, not sent beside it.
        saving = true;
        submit_sent_while_saving = false;
        try {
            sync_editors();
            // Read after the sync: the textareas' change handlers may have written other fields, and saved_hash is the form as sent.
            var hash = get_hash_form();
            var data = $form.serializeObject();
            data._method = post_draft_id ? 'patch' : 'post';
            data.post_id = post_id;
            $.ajax(draft_request(data, hash, callback, called_from_interval, on_failure));
        } catch (e) {
            // The save threw before it was sent (a change handler, a plugin's $.ajax wrapper, a prefilter):
            // nothing will release the lock, and the caller's failure handler is the only way its overlay
            // or window is taken down. The caller is told why the save could not be sent: a failure
            // handler that throws does not replace that error, its own is reported as an uncaught one.
            try { if (on_failure) on_failure(); }
            catch (handler_error) { setTimeout(function () { throw handler_error; }); }
            finally { save_finished(); }
            throw e;
        }
    }

    // The response writes into post_form, the form the save was sent for: with pages loading in place, it
    // may find the editor set up on another form, whose draft id and Preview links are its own.
    function draft_request(data, hash, callback, called_from_interval, on_failure) {
        // The request failed, timed out, or answered without a draft to name. A save the user asked for
        // says it failed; the timer's is retried a minute later. A held submit is sent right after this,
        // and one the fallback wait already sent has gone the same way: the post save reports for itself.
        function request_failed() {
            if (!called_from_interval && !held_form && !submit_sent_while_saving) {
                show_error(I18n("msg.draft_save_failed", "The draft could not be saved"));
            }
            if (on_failure) on_failure();
        }
        return {
            type: 'POST',
            url: _drafts_path,
            data: data,
            // jQuery skips `complete` when a success handler throws, so each handler releases the lock itself.
            success: function (res) {
                try {
                    // The core sends a list of messages; a decorated action may send one, or the model's errors
                    // as they serialize, keyed by field. A refusal names what to fix: one that names nothing
                    // (`{error: []}`, a save a model callback aborted without an error) is a failed request
                    // instead, reported as one and retried by the timer.
                    var messages = res && res.error;
                    if ($.isPlainObject(messages)) {
                        messages = $.map(messages, function (list, field) {
                            return $.map([].concat(list), function (message) { return field + ' ' + message; });
                        });
                    }
                    var refusal = messages ? [].concat(messages).join(", ").trim() : '';
                    if (refusal) {
                        // Render the messages as text ($.fn.alert feeds its title into an HTML sink and a
                        // refusal names the submitted key), and do NOT run the success callback -- it would
                        // navigate away (discarding the unsaved edits) or open a stale preview.
                        // A refused save leaves a held submit on the form (the alert took the overlay down): the
                        // post save would refuse the same content, and the alert names what to fix. A request that
                        // failed or timed out still sends it (see the submit handler). The held submit is not
                        // dispatched again, so a cancelSubmit the validator's click handler set for it (a Cancel or
                        // formnovalidate button) is consumed here, as its own submit handler would have: left set,
                        // it would let the next submit through unvalidated.
                        // A refusal that returns after the fallback wait sent the held submit is not shown: the post
                        // save refuses the same content and re-renders the form with it (see request_failed). A
                        // submit held since (the sent one kept the page, the user submitted again) is left to its
                        // own wait then, as when this save fails or succeeds: dropped here, its overlay would stay
                        // up with no alert to take it down.
                        if (!submit_sent_while_saving) {
                            show_error($('<div>').text(refusal).html());
                            var validator = held_form && $(held_form).data('validator');
                            if (validator) validator.cancelSubmit = false;
                            drop_hold();
                        }
                        // The timer sends nothing until the form changes: sent again, this form would be refused
                        // again, with the same alert (a timer call queued behind this save included). A user's
                        // call is always sent.
                        refused_hash = hash;
                        if (on_failure) on_failure();
                    } else if (!res || !res.draft || res.draft.id == null) {
                        // A decorated drafts action may answer with nothing (`{}`, `null`) or with a draft that
                        // names no id (`{draft: {}}`): no draft to name.
                        request_failed();
                    } else {
                        if (res._drafts_path) _drafts_path = res._drafts_path
                        post_draft_id = res.draft.id
                        saved_hash = hash;
                        refused_hash = null;
                        $(post_form).find("#post_draft_id").val(post_draft_id);
                        set_preview_draft_id();
                        // The fallback wait sent the held submit while this save ran: the post save has the
                        // page from here (as when this save fails, see request_failed), so the callback, which
                        // would leave for the post list or open a preview of a post being saved, does not run;
                        // the failure handler takes down what the caller opened instead.
                        if (submit_sent_while_saving) { if (on_failure) on_failure(); }
                        else if (callback) callback(res);
                    }
                } finally {
                    save_finished();
                }
            },
            error: function () {
                try { request_failed(); } finally { save_finished(); }
            },
            dataType: 'json',
            // A save that has not returned after this long is taken as failed, so a stalled request
            // does not keep the editor from saving or previewing until the browser gives up on it.
            timeout: App_post.save_timeout_ms
        };
    }

    function save_finished() {
        saving = false;
        // The fallback wait sent the held submit while the save ran: the form is submitted, and a save
        // queued behind would write a buffer after the post save removed it (offered for recovery on the
        // next edit) and report for a page the post save has. Each is dropped with its failure handler
        // run, as a queued save for a replaced form is.
        if (submit_sent_while_saving) {
            $.each(queued_saves.splice(0), function (i, queued) { if (queued.on_failure) queued.on_failure(); });
            return;
        }
        // A queued timer call with nothing to send returns without saving, so go on to the next. Each is
        // run from here, not through App_post.save_draft_ajax: a wrapper a plugin put there already ran
        // when the call was made. One that throws before it is sent has run its own failure handler and
        // drained the rest from its own error path; its error is reported as an uncaught one, so it does
        // not replace the error the finished save is raising to its own caller.
        while (!saving && queued_saves.length) {
            var queued = queued_saves.shift();
            try { save_draft_ajax(queued.callback, queued.from_timer, queued.on_failure); }
            catch (drained_error) { setTimeout(function () { throw drained_error; }); }
        }
        if (!held_form) return;
        // A hold that goes on waiting, for the queued save just started, needs the overlay put back: the
        // finished save's caller (Preview, Save Draft) takes it down in its callback.
        if (saving) showLoading(); else send_held_submit();
    }

    // The held submit was stopped before validation and the listeners bound after this script's saw it
    // (see the submit handler), so it is dispatched again in full, as the submit event the browser fires
    // (requestSubmit), with the button that made it as the submitter: validation, those listeners, the
    // ones bound outside jQuery and the ones delegated from an ancestor included (camaleon_admin_ajax
    // submits the form in place from one), and the form's default action run once, now, and the browser
    // sends the button's name, value and formaction itself. A browser without requestSubmit (Safari
    // before 16) gets jQuery's trigger, which reaches jQuery's listeners and the default action; it does
    // not know the button either, SubmitEvent.submitter being as new there.
    // The overlay comes down first: whatever the submit does from here, it does on its own.
    // It is sent to the form it was held on: with pages loading in place, another form can be set up
    // while the hold waits (the browser's Back button is not under the overlay), and one that left the
    // page is not sent at all; the overlay the hold put up still comes down, or the page is dead under it.
    function send_held_submit() {
        var form = held_form, submitter = held_submitter;
        drop_hold();
        hideLoading();
        if (!form || !$.contains(document, form)) return;
        // requestSubmit refuses a submitter that is not a submit button of this form (one a theme re-rendered meanwhile).
        if (!(submitter && submitter.form === form && /^(submit|image)$/i.test(submitter.type))) submitter = null;
        releasing_form = form;
        if (saving) submit_sent_while_saving = true;
        try {
            if (form.requestSubmit) form.requestSubmit(submitter || undefined);
            else $(form).trigger('submit');
        } finally {
            releasing_form = null;
        }
    }

    // The alert takes the overlay down itself ($.fn.alert calls hideLoading).
    function show_error(text) {
        $.fn.alert({type: 'error', title: text, icon: "times"});
    }

    function drop_hold() {
        held_form = null;
        held_submitter = null;
        clearTimeout(submit_wait_timer);
    }

    function set_preview_draft_id() {
        $(post_form).find('.sl-slug-edit .btn-preview').each(function () {
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
            location.href = _posts_path + '?flash[notice]=' + encodeURIComponent(I18n("msg.draft"))
        }, false, hideLoading);
    }
    if(window["post_editor_draft_intrval"]) clearInterval(window["post_editor_draft_intrval"]);
    // Stops once the form has left the page: $form keeps the element after it is removed, so its length says nothing.
    window["post_editor_draft_intrval"] = setInterval(function () { if(!$.contains(document, post_form)){ clearInterval(window["post_editor_draft_intrval"]); } else{ App_post.save_draft_ajax(null, true); } }, 1 * 60 * 1000);
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

    try{$(editor_selector, $form).tinymce().destroy();}catch(e){}
    tinymce.init(cama_get_tinymce_settings({
        selector: editor_selector,
        height: '480px',
        base_path: obj.base_path
    }));

    /*********** control save changes before unload form. ***************/
    // Bound before the validator's handler, so a submit held here is stopped before validation and the
    // listeners bound after this one see it, and each of them runs once, when the held submit is
    // dispatched again. One bound on the form before the editor was set up has seen it by then.
    $form.submit(function (e) {
        // A submit the validator was told to let through (cancelSubmit: a Cancel or formnovalidate
        // button, the recover-draft path below) is let through here too, not validated on its way.
        var validator = $(this).data('validator');
        if (!(validator && validator.cancelSubmit) && !$(this).valid()) return;
        if (saving && releasing_form !== this) {
            if (!held_form) {
                held_form = this;
                // The button the submit came from, when a button made it (a jQuery-triggered submit has none).
                held_submitter = (e.originalEvent && e.originalEvent.submitter) || null;
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
    // Installed with the submit handler, not with the page's later actions a second on: the prompt is
    // this form's own from the moment the editor is set up (an edit typed in that second is asked
    // about, and a form the page loaded in place no longer gets the previous form's answer meanwhile).
    window.onbeforeunload = function () {
        if ($form.data("submitted") || $('#form-post').length == 0)
            return;
        if (form_edited()) {
            return "You sure to leave the page without saving changes?";
        }
    };

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
            // The touch listeners have done their work: from here the form is compared.
            tinymce.off('AddEditor', watch_editor_touch);
            $.each(tinymce.editors, function (i, editor) { editor.off('init', check); editor.off('change', mark_editor_touched); });
            post_form.removeEventListener('input', mark_touched);
            post_form.removeEventListener('change', mark_touched);
            // The editor was set up on another form meanwhile (admin pages load in place, and the form
            // read here is the one the script was last set up on): that form takes its own baseline.
            if ($form[0] !== post_form) return;
            var hash = get_hash_form();
            // The user edited the form while it was still being set up: this baseline reads the edit as
            // the original. The form stays edited (form_edited), and the timer sends it, since the saved
            // state is set to match no form.
            if (touched) edited_before_baseline = true;
            // A draft save that ran meanwhile already recorded what it sent; later edits are still unsaved.
            if (saved_hash === null) saved_hash = edited_before_baseline ? '' : hash;
            $form.data("hash", hash);
        }
        function check() { if (!taken && ($form[0] !== post_form || editors_ready())) take_baseline(); }
        function watch_editor(e) { e.editor.on('init', check); }
        tinymce.on('AddEditor', watch_editor);
        $.each(tinymce.editors, function (i, editor) { if (!editor.initialized) editor.on('init', check); });
        check();
    }

    // The leave prompt's question. Before the baseline the form is still being set up (an editor coming
    // up normalizes its textarea, a widget writes its value), so a comparison would read setup as an
    // edit: until then the form counts as edited when the user typed or clicked in it, or in one of its
    // editors (see mark_touched and mark_editor_touched).
    function form_edited() {
        if (edited_before_baseline) return true;
        if ($form.data("hash") === undefined) return touched;
        return $form.data("hash") != get_hash_form();
    }

    function editors_ready() {
        var ready = true;
        // A textarea the editor has not been created for yet; one created but still loading is caught below.
        $(post_form).find(editor_selector).each(function () {
            if (!tinymce.get(this.id)) ready = false;
        });
        $.each(tinymce.editors, function (i, editor) {
            if (!editor.initialized && in_form(editor)) ready = false;
        });
        return ready;
    }

    // Only the form's editors are the post's content: one a plugin puts elsewhere on the page (a modal)
    // is neither compared nor sent. The form is the one this setup owns (post_form), as for every read
    // and write below: $form may be a form the page loaded in place since.
    function in_form(editor) {
        return $.contains(post_form, editor.getElement());
    }

    // The form's editors that have come up: what is compared and what is sent. One still loading is
    // left to its textarea, which holds the server value. $.grep walks the indexes only: TinyMCE keys
    // the array by editor id too, so for..in visits each twice.
    function form_editors() {
        return $.grep(tinymce.editors, function (editor) { return editor.initialized && in_form(editor); });
    }

    // A read: each editor's content is taken from the editor and its textarea is left alone, so what a
    // plugin wrote into a textarea itself is not rewritten in TinyMCE's serialization by a comparison.
    // Left out: the draft id (a save filling it in is not an edit) and the hidden original of a
    // translated field, composed from the per-language copies that are read.
    function get_hash_form() {
        var editors = {};
        $.each(form_editors(), function (i, editor) { editors[editor.id] = editor.getContent(); });
        // An own-property check: `in` would also match an id every object inherits, like `constructor`.
        var fields = $(post_form).find(':input').not('#post_draft_id, .translated-item').filter(function () {
            return !Object.prototype.hasOwnProperty.call(editors, this.id);
        });
        return fields.serialize() + '&' + $.param(editors);
    }

    // Before the form is serialized for a save: each editor's content goes into its textarea, and
    // through the textarea's change handlers into the hidden original of a translated field. The other
    // translated fields compose their originals too, through the event their copies keep for it
    // (change_in; a change would also run the copy's other handlers, the title's slug lookup): a copy
    // still being typed in fires no change until it loses focus, and the comparison reads the copies,
    // not the originals, so the original composed then would never be sent. Any one copy composes its
    // whole field (the translator's panel), so one is asked per field.
    function sync_editors() {
        var synced = $.map(form_editors(), function (editor) {
            $(editor.getElement()).val(editor.getContent()).trigger("change");
            return editor.getElement();
        });
        $(post_form).find('.trans_panel').each(function () {
            $(this).find('.translate-item').not(synced).first().trigger('change_in');
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
