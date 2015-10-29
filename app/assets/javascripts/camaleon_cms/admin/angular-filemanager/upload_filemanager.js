!(function ($) {
    $.fn.upload_filemanager_dispatcher = {
        onSelectedCallback: null,
        dispatch: function (eventName, element) {
            switch (eventName) {
                case 'smartClick':
                    if ($.fn.upload_filemanager_dispatcher.onSelectedCallback != null) {
                        var item = {
                            mime: 'image/png', //FIXME calculate mimetype
                            url: element.model.fullPath(),
                            type: element.model.type
                        };
                        $.fn.upload_filemanager_dispatcher.onSelectedCallback(item, function (result) {
                            if (result == true) {
                                $('#modal_filemanager').modal('hide');
                            }
                        });
                    }
                    break;
                default:
                    console.log('New log NAME: ' + eventName + ' ELEMENT: ' + element);
            }
        }
    };

    $.fn.upload_filemanager = function (options) {
        var filemanager_loader_scope = angular.element(document.getElementById('filemanager-container')).scope();

        filemanager_loader_scope.include('');
        filemanager_loader_scope.config = {};

        if (options.selected) {
            $.fn.upload_filemanager_dispatcher.onSelectedCallback = options.selected;
        }

        var layout = (typeof options.layout === 'function') ? options.layout() : options.layout;
        if (layout == 'images') {
            filemanager_loader_scope.config.mimeFilter = 'images';
            filemanager_loader_scope.config.autoImagePreview = false;
            filemanager_loader_scope.include('/admin/filemanager/view/modal_images');
        } else if (layout == 'media' || layout == 'videos') {
            filemanager_loader_scope.config.mimeFilter = 'videos';
            filemanager_loader_scope.include('/admin/filemanager/view/modal_images');
        } else if (layout == 'images_or_upload') {
            filemanager_loader_scope.config.mimeFilter = 'images';
            filemanager_loader_scope.config.allowedActions = {navbar: {newFolder: false, uploadFile: true}};
            filemanager_loader_scope.include('/admin/filemanager/view/modal_images');
        } else if (layout == 'user_images_or_upload') {
            if (options.user_pwd != null) {
                filemanager_loader_scope.config.pwd = options.user_pwd;
                filemanager_loader_scope.config.mimeFilter = 'images';
                filemanager_loader_scope.config.allowedActions = {navbar: {newFolder: false, uploadFile: true}};
                filemanager_loader_scope.include('/admin/filemanager/view/modal_images');
            } else {
                console.error('Trying to show user_images_or_upload layout without valid user_pwd');
            }
        } else {
            console.log('Unexpected layout: ' + layout);
            filemanager_loader_scope.config.mimeFilter = 'none';
            filemanager_loader_scope.include('/admin/filemanager/view/default');
        }
    }
})(jQuery);