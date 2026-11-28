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
            
            // The editor writes an empty paragraph with no attributes as a line break.
            // - The text of a script or a comment can contain "<p></p>". That text must not change.
            //   For this reason, the paragraphs are marked as elements, not found in the output text.
            // - The serializer of the editor parses the content, its filters change the parsed
            //   elements, and then it writes them. The filters for different element names run in
            //   the sequence in which the content names them first. Thus other filters can empty a
            //   paragraph after this filter, for example the filter that removes the last "br" of a
            //   block, or the filter that removes bookmarks.
            // - For this reason, this filter only gives each paragraph an attribute with a random
            //   value. The value is the same for all the content of one editor. No other filter
            //   reads this attribute, so the other filters change the same elements as before. A
            //   paragraph that has this attribute in the content keeps it and gets no mark.
            // - PostProcess gets the output text. A paragraph that has only this attribute and no
            //   content becomes a line break. Then the attribute is removed from all paragraphs.
            // - Without PostProcess (no_events, or a tree), the filter does nothing.
            var paragraph_mark = Math.random().toString(36).slice(2);
            var paragraph_mark_text = ' data-cama-paragraph="' + paragraph_mark + '"';
            editor.on('PreInit', function () {
                editor.serializer.addNodeFilter('p', function (nodes, name, args) {
                    if (args.no_events || args.format === 'tree') return;
                    for (var i = 0; i < nodes.length; i++) {
                        if (!('data-cama-paragraph' in nodes[i].attributes.map)) nodes[i].attr('data-cama-paragraph', paragraph_mark);
                    }
                });
            });
            editor.on('PostProcess', function (e) {
                e.content = e.content.split('<p' + paragraph_mark_text + '></p>').join('<br />').split(paragraph_mark_text).join('');
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