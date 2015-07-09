function open_elfinder(options, callback){
    if(typeof options == "undefined") options = {title: 'Upload File'};
    var modal = $('<div class="modal fade">'+
    '<div class="modal-dialog" style="width: 90%; max-width: 1100px">'+
    '<div class="modal-content">'+
    '<div class="modal-header">'+
    '<button type="button" class="close" data-dismiss="modal" aria-hidden="true">&times;</button>'+
    '<h4 class="modal-title">' + options.title + '</h4>'+
    '</div>'+
    '<div class="modal-body overflow-visible" style="padding: 0">' +
    '<iframe frameborder="0" src="/admin/elfinder/iframe?'+jQuery.param(options)+'" style="width: 100%; height: 462px; overflow: hidden; border: none" />'+
    '</div>'+
    '</div>'+
    '</div>'+
    '</div>');

    // close all modals
    $('.modal').modal('hide');
    // open modal
    modal.modal();
    // set iframe window
    // modal.find('iframe')[0].contentWindow
    //modal.find('iframe')[0].onload = function (e){  }

    window.callback_modal_elfinder = function(data){
        modal.modal('hide');
        if(typeof callback == "function") callback(data);
    }
}