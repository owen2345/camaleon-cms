var App_post = {};
var $form = null;
function cama_init_post(obj) {
    $form = $('#form-post');

    if (obj.recover_draft == "true") {
        $form.css('opacity', 0).before('<h2 style="text-align: center">' + I18n("msg.recover") + '</h2>');
    }

    var class_translate = ".translate-item";
    // The textareas TinyMCE turns into the form's editors.
    var editor_selector = '.tinymce_textarea:not(.translated-item)';

    var post_id = obj.post_id;
    var post_draft_id = obj.post_draft_id;
    var post_status = obj.post_status;
    var _drafts_path = obj._drafts_path;
    var _posts_path = obj._posts_path;
    var _ajax_path = obj._ajax_path;
    var _post_tags_path = obj._post_tags_path;

    // How the form is tracked. get_hash_form serializes it. data("hash") is the baseline, taken once the
    // editors are ready; the leave-page prompt compares against it. saved_hash is what the last successful
    // draft save sent and refused_hash what the last refused one sent: the minute timer sends only a form
    // that differs from both. One save runs at a time: a save asked for meanwhile is queued, and a submit
    // made meanwhile is held until the save returns or App_post.submit_wait_ms passes (the save is aborted
    // then). A save that has not returned after App_post.save_timeout_ms fails.
    var saved_hash = null;
    var refused_hash = null;
    // The user typed or clicked in the form before the baseline (a native input or change event; a script's
    // write or jQuery's trigger fires none).
    var touched = false;
    // The baseline absorbed an edit made before it was taken: the form counts as edited until submitted.
    var edited_before_baseline = false;
    var saving = false;
    var queued_saves = [];
    var submit_wait_timer = null;
    var held_form = null;
    var held_submitter = null;
    var releasing_form = null;
    // The jqXHR of the running save, for send_held_submit to abort.
    var running_request = null;
    // The form this setup owns. Admin pages load in place, so $form may already be another post's form
    // when a save of this one returns or is drained from the queue.
    var post_form = $form[0];
    post_form.addEventListener('input', mark_touched);
    post_form.addEventListener('change', mark_touched);
    function mark_touched() { touched = true; }
    // Typing in an editor fires nothing on the form (its document is the iframe's), so the editor's own
    // change event is watched: it fires for typing, pasting and formatting, not for a script's setContent.
    // Its dirty flag would not do: TinyMCE clears it whenever the content is saved into the textarea,
    // which happens on blur.
    function mark_editor_touched(e) { if ($.contains(post_form, e.target.getElement())) touched = true; }
    function watch_editor_touch(e) { e.editor.on('change', mark_editor_touched); }
    tinymce.on('AddEditor', watch_editor_touch);
    $.each(tinymce.editors, function (i, editor) { editor.on('change', mark_editor_touched); });
    // Defaults; a value a plugin or theme set first is kept, zero included.
    if (App_post.submit_wait_ms == null) App_post.submit_wait_ms = 15000;
    if (App_post.save_timeout_ms == null) App_post.save_timeout_ms = 30000;

    // on_failure runs when the save is refused, fails, is aborted, is dropped or could not be sent.
    App_post.save_draft_ajax = save_draft_ajax;
    function save_draft_ajax(callback, called_from_interval, on_failure) {
        // The page loaded another post's form in place: serializing it would send that post's content to
        // this draft. Dropped at once, so the caller's failure handler (which closes a Preview window or the
        // overlay) does not wait behind a save that is not its own.
        if ($form[0] !== post_form) {
            if (on_failure) on_failure();
            return;
        }
        if (saving) {
            // One timer call in the queue is enough: it compares the form once when drained.
            if (called_from_interval && $.grep(queued_saves, function (queued) { return queued.from_timer; }).length) return;
            queued_saves.push({callback: callback, from_timer: called_from_interval, on_failure: on_failure});
            return;
        }
        if (called_from_interval) {
            // Nothing before the baseline, and nothing once the form is submitted: a buffer written while
            // the post save is pending is not discarded by it and shows up under Drafts as a newer edit.
            if (saved_hash === null || $form.data("submitted")) return;
            var current = get_hash_form();
            if (current == saved_hash || current == refused_hash) return;
        }

        // Locked before the sync, so a save a change handler asks for queues instead of running beside this one.
        saving = true;
        try {
            sync_editors();
            // Read after the sync: change handlers may have written other fields; saved_hash must be the form as sent.
            var hash = get_hash_form();
            var data = $form.serializeObject();
            data._method = post_draft_id ? 'patch' : 'post';
            data.post_id = post_id;
            var request = $.ajax(draft_request(data, hash, callback, called_from_interval, on_failure));
            // jQuery answers a request it cannot send inside $.ajax (a beforeSend that returns false, a
            // transport that throws): this save has finished by then, and a save drained from the queue may
            // own running_request. It is set only while this save runs.
            if (saving && running_request === null) running_request = request;
        } catch (e) {
            // Thrown before the send (a change handler, a $.ajax wrapper): release the lock, let the caller's
            // failure handler close what it opened, and rethrow. A failure handler that throws must not
            // replace the send's error, so its own is reported separately.
            try { if (on_failure) on_failure(); }
            catch (handler_error) { report_later(handler_error); }
            finally { save_finished(); }
            throw e;
        }
    }

    // The response writes into post_form, the form it was sent for, even if $form is another form by then.
    function draft_request(data, hash, callback, called_from_interval, on_failure) {
        // Failed, timed out, or answered with no draft. A save the user asked for says so; the timer's is
        // retried a minute later. No alert while a submit is held: it goes out next and reports for itself.
        function request_failed() {
            if (!called_from_interval && !held_form) {
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
                    // The core refuses with a list of messages; a decorated action may send one message or the
                    // model's errors keyed by field. A refusal with no message (`{error: []}`) is a failed
                    // request instead.
                    var messages = res && res.error;
                    if ($.isPlainObject(messages)) {
                        messages = $.map(messages, function (list, field) {
                            return $.map([].concat(list), function (message) { return field + ' ' + message; });
                        });
                    }
                    var refusal = messages ? [].concat(messages).join(", ").trim() : '';
                    if (refusal) {
                        // Shown as text ($.fn.alert puts its title into HTML, and a refusal quotes user input).
                        // The callback does not run: it would leave the page or open a stale preview. A held
                        // submit is dropped, since the post save would refuse the same content; the alert took
                        // the overlay down. A cancelSubmit the validator set for that submit (a Cancel or
                        // formnovalidate button) is reset here, as the validator's own handler would have done.
                        show_error($('<div>').text(refusal).html());
                        var validator = held_form && $(held_form).data('validator');
                        if (validator) validator.cancelSubmit = false;
                        drop_hold();
                        // The timer sends nothing until the form changes; re-sent, it would be refused again.
                        refused_hash = hash;
                        if (on_failure) on_failure();
                    } else if (!res || !res.draft || res.draft.id == null) {
                        // A decorated drafts action may answer with no draft to name (`{}`, `null`, `{draft: {}}`).
                        request_failed();
                    } else {
                        if (res._drafts_path) _drafts_path = res._drafts_path
                        post_draft_id = res.draft.id
                        saved_hash = hash;
                        refused_hash = null;
                        $(post_form).find("#post_draft_id").val(post_draft_id);
                        set_preview_draft_id();
                        if (callback) callback(res);
                    }
                } finally {
                    save_finished();
                }
            },
            // Status 'submit': aborted by send_held_submit, which sends the held submit next. The post save
            // reports for itself, so no alert; the failure handler closes what the caller opened.
            error: function (xhr, status) {
                var for_submit = status === 'submit';
                try { if (for_submit) { if (on_failure) on_failure(); } else { request_failed(); } }
                finally { save_finished(for_submit); }
            },
            dataType: 'json',
            // A stalled request must not keep the editor from saving or previewing until the browser gives up.
            timeout: App_post.save_timeout_ms
        };
    }

    // Reports an error raised on another save's path (a failure handler, a queued save) as an uncaught one,
    // so it does not replace the error that save is raising to its own caller.
    function report_later(error) {
        setTimeout(function () { throw error; });
    }

    // for_submit: the save was aborted because the held submit goes out next (see send_held_submit).
    function save_finished(for_submit) {
        saving = false;
        running_request = null;
        if (for_submit) {
            // The form is being submitted: a queued save would write a buffer the post save leaves behind.
            // Each is dropped with its failure handler run; one that throws does not stop the others.
            $.each(queued_saves.splice(0), function (i, queued) {
                try { if (queued.on_failure) queued.on_failure(); }
                catch (handler_error) { report_later(handler_error); }
            });
        } else {
            // A queued timer call may find nothing to send and return at once, so keep going. Queued saves
            // run through the local function: a plugin's wrapper on App_post.save_draft_ajax already ran
            // when they were called. One that throws has drained the rest from its own error path; its
            // error is reported separately, since this may run inside the finished save's own error path.
            while (!saving && queued_saves.length) {
                var queued = queued_saves.shift();
                try { save_draft_ajax(queued.callback, queued.from_timer, queued.on_failure); }
                catch (drained_error) { report_later(drained_error); }
            }
        }
        if (!held_form) return;
        // A hold that waits on for a queued save needs the overlay back: the finished save's caller took it down.
        if (saving) showLoading(); else send_held_submit();
    }

    // Dispatches the held submit in full, as the browser would (requestSubmit, with the button that made it
    // as the submitter): validation, every listener bound after the hold handler (delegated and native ones
    // included; camaleon_admin_ajax submits the form in place from one on the body) and the default action
    // run once, now, and the browser sends the button's name, value and formaction. Safari before 16 has
    // no requestSubmit and gets jQuery's trigger, which reaches jQuery's listeners and the default action.
    // The overlay comes down first. A save still running (the fallback wait ran out) is aborted: the post
    // save reports for itself from here, and a late answer would run the save's callback (Save Draft's
    // leaves the page) or show an alert over a page being replaced. A held form that left the page
    // (another page loaded in place while the hold waited) is not sent.
    function send_held_submit() {
        var form = held_form, submitter = held_submitter;
        drop_hold();
        hideLoading();
        if (!$.contains(document, form)) return;
        // requestSubmit throws on a submitter that is not a submit button of this form (a theme may have re-rendered it).
        if (!(submitter && submitter.form === form && /^(submit|image)$/i.test(submitter.type))) submitter = null;
        if (saving && running_request && running_request.abort) {
            // The error handler runs inside abort with this status; an error thrown there must not stop the submit.
            try { running_request.abort('submit'); } catch (e) { report_later(e); }
        }
        releasing_form = form;
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

    // Under the overlay while it saves: the callback leaves the page, and an edit made meanwhile would be lost.
    App_post.save_draft = function () {
        showLoading();
        App_post.save_draft_ajax(function () {
            // Another form was loaded in place meanwhile (Back is not under the overlay): leave it its page.
            if ($form[0] !== post_form) { hideLoading(); return; }
            $form.data("submitted", 1);
            location.href = _posts_path + '?flash[notice]=' + encodeURIComponent(I18n("msg.draft"))
        }, false, hideLoading);
    }
    if(window["post_editor_draft_intrval"]) clearInterval(window["post_editor_draft_intrval"]);
    // Stops once the form has left the page ($form still holds the removed element, so its length says nothing).
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
                // Prevented first: if the save throws, the link (naming no draft yet) must not open in a tab.
                e.preventDefault();
                var link = $(this);
                // Opened in the click: a popup blocker refuses a window opened from the async callback.
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
    // Bound before the validator's handler: a held submit is stopped before validation and before the
    // listeners bound after this one see it, so each runs once, when the submit is dispatched again.
    $form.submit(function (e) {
        // cancelSubmit (a Cancel or formnovalidate button, the recover-draft path below): the validator
        // lets it through unvalidated, so it is not validated here either.
        var validator = $(this).data('validator');
        if (!(validator && validator.cancelSubmit) && !$(this).valid()) return;
        if (saving && releasing_form !== this) {
            if (!held_form) {
                held_form = this;
                // The button that made the submit; a jQuery-triggered submit has none.
                held_submitter = (e.originalEvent && e.originalEvent.submitter) || null;
                showLoading();
                // A stalled save must not block the post; a new post may lose that save's buffer, the lesser loss.
                submit_wait_timer = setTimeout(send_held_submit, App_post.submit_wait_ms);
            }
            e.preventDefault();
            e.stopImmediatePropagation();
            return;
        }
        $(this).data("submitted", 1);
    });
    // Installed now, not a second later with form_later_actions, so the prompt is this form's from the start.
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

    // An editor normalizes its textarea when it comes up, so the baseline waits until every editor on the
    // form has initialized (re-checked on each init), or ten seconds at most.
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
            // Another form was set up meanwhile (pages load in place); it takes its own baseline.
            if ($form[0] !== post_form) return;
            var hash = get_hash_form();
            // The user edited the form during setup, so this baseline absorbs the edit: the form stays
            // edited (form_edited) and saved_hash matches nothing, so the timer sends it.
            if (touched) edited_before_baseline = true;
            // A save that already ran keeps its own saved_hash.
            if (saved_hash === null) saved_hash = edited_before_baseline ? '' : hash;
            $form.data("hash", hash);
        }
        function check() { if (!taken && ($form[0] !== post_form || editors_ready())) take_baseline(); }
        function watch_editor(e) { e.editor.on('init', check); }
        tinymce.on('AddEditor', watch_editor);
        $.each(tinymce.editors, function (i, editor) { if (!editor.initialized) editor.on('init', check); });
        check();
    }

    // The leave prompt's question. Before the baseline, setup writes (an editor normalizing its textarea,
    // a widget writing its value) would read as edits, so only the user's own input counts then.
    function form_edited() {
        if (edited_before_baseline) return true;
        if ($form.data("hash") === undefined) return touched;
        return $form.data("hash") != get_hash_form();
    }

    function editors_ready() {
        var ready = true;
        // A textarea with no editor yet; one still loading is caught below.
        $(post_form).find(editor_selector).each(function () {
            if (!tinymce.get(this.id)) ready = false;
        });
        $.each(tinymce.editors, function (i, editor) {
            if (!editor.initialized && in_form(editor)) ready = false;
        });
        return ready;
    }

    // Only editors inside post_form are the post's content; a plugin's editor elsewhere (a modal) is not.
    function in_form(editor) {
        return $.contains(post_form, editor.getElement());
    }

    // The form's initialized editors. One still loading is left to its textarea, which holds the server
    // value. $.grep walks indexes only; TinyMCE also keys the array by id, so for..in would visit each twice.
    function form_editors() {
        return $.grep(tinymce.editors, function (editor) { return editor.initialized && in_form(editor); });
    }

    // A read only: editors are read from TinyMCE and their textareas left alone, so content a plugin wrote
    // into a textarea is not rewritten by a comparison. Left out: the draft id (filled in by a save, not an
    // edit) and a translated field's hidden original (composed from the copies, which are read).
    function get_hash_form() {
        var editors = {};
        $.each(form_editors(), function (i, editor) { editors[editor.id] = editor.getContent(); });
        // form.elements: the controls the browser sends, including one elsewhere on the page with
        // form="form-post". Fieldsets are dropped: jQuery would serialize their controls a second time, an
        // editor's stale textarea among them. hasOwnProperty, since `in` would match an inherited name like
        // `constructor`.
        var fields = $(post_form.elements).filter(':input').not('#post_draft_id, .translated-item').filter(function () {
            return !Object.prototype.hasOwnProperty.call(editors, this.id);
        });
        return fields.serialize() + '&' + $.param(editors);
    }

    // Before a save is serialized: each editor's content goes into its textarea, and every translated
    // field's hidden original is recomposed from its copies (change_in, the translator's own event; change
    // would also run the title's slug lookup). A copy still being typed in has fired no change yet, and
    // the comparison reads the copies, so a stale original would never be resent. One copy per panel
    // recomposes the whole field.
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
