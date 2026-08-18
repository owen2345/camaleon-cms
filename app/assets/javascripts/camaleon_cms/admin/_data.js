function cama_get_tinymce_settings(settings){
    if(!settings) settings = {};
    var def = {
        selector: ".tinymce_textarea",
        plugins: "advlist autolink lists link image charmap print preview hr anchor pagebreak searchreplace wordcount visualblocks visualchars code fullscreen insertdatetime media nonbreaking save table contextmenu directionality emoticons template paste textcolor colorpicker textpattern filemanager",
        menubar: "edit insert view format table tools",
        image_advtab: true,
        statusbar: true,
        paste: true,
        toolbar_items_size: 'small',
        content_css: tinymce_global_settings["custom_css"].join(","),
        convert_urls: false,
        //forced_root_block: '',
        extended_valid_elements: 'i[*],div[*],p[*],li[*],a[*],ol[*],ul[*],span[*]',
        toolbar: "bold italic | alignleft aligncenter alignright alignjustify | fontselect fontsizeselect | bullist numlist | outdent indent | undo redo | link unlink image media | forecolor backcolor | styleselect template "+tinymce_global_settings["custom_toolbar"].join(","),
        image_caption: true,
        language: CURRENT_LOCALE,
        relative_urls: false,
        remove_script_host: false,
        browser_spellcheck : true,
        language_url: tinymce_global_settings["language_url"],
        file_browser_callback: function(field_name, url, type, win) {
            $.fn.upload_filemanager({
                formats: type,
                selected: function(file, response){
                    $('#' + field_name).val(file.url);
                }
            });
        },
        fix_list_elements: true,
        setup: function (editor) {
            editor.on('blur', function () {
                tinymce.triggerSave();
                $('textarea#'+editor.id).trigger('change');
            });
            
            editor.on('PostProcess', function (ed) {
                ed.content = ed.content.replace(/(<p><\/p>)/gi,'<br />');
            });

            editor.addMenuItem('append_line', {
                text: 'New line at the end',
                context: 'insert',
                onclick: function () { editor.dom.add(editor.getBody(), 'p', {}, '-New line-');  }
            });
            editor.addMenuItem('add_line', {
                text: 'New line',
                context: 'insert',
                onclick: function () { editor.insertContent('<p>-New line-</p>');  }
            });

            // eval all extra setups
            for(var ff in tinymce_global_settings["setups"]) tinymce_global_settings["setups"][ff](editor);

            editor.on('postRender', function(e) {
                editor.settings.onPostRender(editor);
                // eval all extra setups
                for(var ff in tinymce_global_settings["post_render"]) tinymce_global_settings["post_render"][ff](editor);
            });

            editor.on('init', function(e) {
                for(var ff in tinymce_global_settings["init"]) tinymce_global_settings["init"][ff](editor);

                // Content guard for the cold-boot / background-tab init race: when the edit form is
                // opened in a background tab on a cold server, the browser throttles the tab and
                // TinyMCE can initialize empty even though the server rendered the post content into
                // the textarea -- the field's live value is blanked before TinyMCE reads it. The
                // DOM still holds the server value in `defaultValue`, so restore it when the editor
                // came up empty but the server value did not. Skip Translatable clones and encoded
                // multi-language values (leading `<!--:`), whose per-locale decoding Translatable owns.
                var ta = document.getElementById(editor.id);
                if (ta && !ta.classList.contains('translate-item') &&
                    (editor.getContent() || '').length === 0 &&
                    (ta.defaultValue || '').length > 0 &&
                    ta.defaultValue.indexOf('<!--:') !== 0) {
                    editor.setContent(ta.defaultValue);
                    editor.save();
                }
            });
        },
        onPostRender: function(editor){}
    };
    for(var ff in tinymce_global_settings["settings"]) tinymce_global_settings["settings"][ff](settings, def);
    return $.extend({}, def, settings);
}