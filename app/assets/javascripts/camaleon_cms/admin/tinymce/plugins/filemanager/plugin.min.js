tinymce.PluginManager.add('filemanager', function(editor) {
    function openmanager() {
        var dom = editor.dom;
        $.fn.upload_filemanager({
            selected: function(file){
                var linkAttrs = {
                    href: file.url,
                    target:  '_blank',
                    rel:  null,
                    "class": null,
                    title:  file.name
                }
                editor.insertContent(dom.createHTML('a', linkAttrs, dom.encode(file.name)));
            }
        });
    }
    editor.addButton('filemanager', {
        icon: 'browse',
        tooltip: 'Insert file',
        onclick: openmanager,
        stateSelector: 'img:not([data-mce-object])'
    });
    editor.addMenuItem('filemanager', {
        icon: 'browse',
        text: 'Insert file',
        onclick: openmanager,
        context: 'insert',
        prependToContext: true
    })
});
