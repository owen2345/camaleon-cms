!(function ($) {
    $.fn.upload_filemanager = function (options) {
        console.log('Init upload_filemanager: ' + JSON.stringify(options));
        //FIXME configure modal with options
        //$('#modal_filemanager').modal('show');
        angular.element(document.getElementById('filemanager-container')).scope().include('/admin/filemanager/main');

        /*
         var $content = $(this);

         var init_filemanager = function () {
         angular.module('FileManagerApp').config(['fileManagerConfigProvider'], function (config) {
         config.set({
         appName: 'camaleon-cms',
         listUrl: 'filemanager/handler',
         uploadUrl: 'filemanager/upload',
         renameUrl: 'filemanager/handler',
         copyUrl: 'filemanager/handler',
         removeUrl: 'filemanager/handler',
         editUrl: 'filemanager/handler',
         getContentUrl: 'filemanager/handler',
         createFolderUrl: 'filemanager/handler',
         downloadFileUrl: 'filemanager/download',
         compressUrl: 'filemanager/handler',
         extractUrl: 'filemanager/handler',
         permissionsUrl: 'filemanager/handler',
         tplPath: 'filemanager/templates'
         });
         });
         };

         if ($content.size()) {
         var modal_filemanager = false;
         init_filemanager();
         } else {
         var html = '<div id="modal_filemanager" class="modal fade bs-example-modal-lg" tabindex="-1" role="dialog" aria-labelledby="myLargeModalLabel" aria-hidden="true">' +
         '<div class="modal-dialog modal-lg">' +
         '<div class="modal-content">' +
         '<div class="modal-header">' +
         '<button type="button" class="close" data-dismiss="modal"><span aria-hidden="true">&times;</span><span class="sr-only">Close</span></button>' +
         '<h4 class="modal-title" id="defModalHead">Media</h4>' +
         '</div>' +
         '<div data-ng-app="FileManagerApp"><angular-filemanager></angular-filemanager></div>' +
         '</div>' +
         '</div>' +
         '</div>';
         var modal_filemanger = $(html);
         modal_filemanger.modal();
         modal_filemanger.on('shown.bs.modal', function () {
         $content = $('#modal_filemanager').find('#content_filemanager');
         init_filemanager();
         });
         modal_filemanger.on('hidden.bs.modal', function () {
         $('#modal_filemanager').remove();
         try {
         modal_fix_multiple();
         } catch (ignore) {

         }
         });
         }
         */
    }
})(jQuery);