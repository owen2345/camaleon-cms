var App_post = {};
var $form = null;
function cama_init_post(obj) {
    $form = $('#form-post');

    if (obj.recover_draft == "true") {
        $form.css('opacity', 0).before('<h2 style="text-align: center">' + I18n("msg.recover") + '</h2>');
    }

    var _draft_inited = false;
    var class_translate = ".translate-item";

    var post_id = obj.post_id;
    var post_draft_id = obj.post_draft_id;
    var post_status = obj.post_status;
    var _drafts_path = obj._drafts_path;
    var _posts_path = obj._posts_path;
    var _ajax_path = obj._ajax_path;
    var _post_tags_path = obj._post_tags_path;

    App_post.save_draft_ajax = function (callback, called_from_interval) {
        _draft_inited = true;
        var data = $form.serializeObject();
        data._method = post_draft_id ? 'patch' : 'post';
        data.post_id = post_id;
        if ($form.data("hash") != get_hash_form() || !called_from_interval) {
            $.ajax({
                type: 'POST',
                url: _drafts_path,
                data: data,
                success: function (res) {
                    if (res.error) {
                        $.fn.alert({type: 'error', title: res.error.join(", "), icon: "times"})
                    } else {
                        if (res._drafts_path) _drafts_path = res._drafts_path
                        post_draft_id = res.draft.id
                        $("#post_draft_id").val(post_draft_id);
                    }
                    if (callback) callback(res);
                },
                dataType: 'json',
                async: false
            });
        }

    };

    App_post.save_draft = function () {
        App_post.save_draft_ajax(function () {
            $form.data("submitted", 1);
            location.href = _posts_path + '?flash[notice]=' + I18n("msg.draft")
        });

    }
    if(window["post_editor_draft_intrval"]) clearInterval(window["post_editor_draft_intrval"]);
    window["post_editor_draft_intrval"] = setInterval(function () { if($form.length == 0){ clearInterval(window["post_editor_draft_intrval"]); } else{ App_post.save_draft_ajax(null, true); } }, 1 * 60 * 1000);
    window.save_draft = App_post.save_draft_ajax;

    if($form.find(".title-post" + class_translate).size() == 0) class_translate = '';
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
                showLoading();
                App_post.save_draft_ajax(function(){
                    hideLoading();
                    var ar = link.attr("href").split("draft_id=");
                    ar[1] = post_draft_id;
                    var clone = link.clone().hide();
                    clone.insertAfter(link).attr('href', ar.join("draft_id="))[0].click();
                    clone.remove();
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

        // sidebar toggle
        //$("#admin_content #post_right_bar-toggle").on("click", function () {
        //    $("#post_right_bar").is(":visible") ? $("#post_right_bar").hide() : $("#post_right_bar").show();
        //});

        /*********** control save changes before unload form. ***************/
        $form.submit(function () {
            if ($(this).valid()) $form.data("submitted", 1);
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
            $.get($form.find("#post_add_new_category").data('reload-url'), {categories: panel_cats.find("input:checkbox:checked").map(function(i, el){ return $(this).val(); }).get()}, function(res){ panel_cats.html(res); });
        }});
        /*********** end *************/
    }
    setTimeout(form_later_actions, 1000);
    setTimeout(function(){ $form.data("hash", get_hash_form()); }, 2000);

    function get_hash_form() {
        for (editor in tinymce.editors) {
            editor = tinymce.editors[editor];
            var i = $("#" + editor.id).val(tinymce.get(editor.id).getContent()).trigger("change");
        }
        return $form.serialize();
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