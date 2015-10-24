!(function ($) {
    $.fn.upload_filemanager_dispatcher = {
        onSelectedCallback: null,
        dispatch: function (eventName, element) {
            switch (eventName) {
                case 'smartClick':
                    if ($.fn.upload_filemanager_dispatcher.onSelectedCallback != null) {
                        $.fn.upload_filemanager_dispatcher.onSelectedCallback(element);
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

        if (typeof options.type != 'undefined') {
            switch (options.type) {
                case "audio":
                    break;
                default:
                    console.error('Unexpected type of files: ' + options.type);
            }
        } else {
            filemanager_loader_scope.config.mimeFilter = 'none';
        }

        if (options.selected) {
            $.fn.upload_filemanager_dispatcher.onSelectedCallback = options.selected;
        }

        if (options.layout == 'images') {
            filemanager_loader_scope.config.mimeFilter = 'images';
            filemanager_loader_scope.include('/admin/filemanager/view/modal_images');
        } else {
            filemanager_loader_scope.config.mimeFilter = 'none';
            filemanager_loader_scope.include('/admin/filemanager/view/default');
        }
    }
})(jQuery);