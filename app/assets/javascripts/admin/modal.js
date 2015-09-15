
/*
 * PLUGIN FOR SHOW LINK CONTENTS INTO MODAL
 * add events to links for open their content by ajax into modal
 * use: <a class='my_link' href='mylink' title='my title' data-show_footer='true'>
 * $(".my_link").ajax_modal({settings});
 * settings: check open_modal(settings)
 */
jQuery(function(){
    $.fn.ajax_modal = function(settings){
        $(this).click(function(e){
            var title = $(this).attr("title");
            title = (title == "")? $(this).attr("data-original-title") : title
            var def = {title: title?title:$(this).data("title"), mode: "ajax", url: $(this).attr("href"), show_footer: $(this).data("show_footer")};
            var c_settings = $.extend({}, def, settings);
            open_modal(c_settings);
            e.preventDefault();
        });
    }
});


/*********** METHOD FOR OPEN A MODAL WITH CONTENT OR FETCH FROM A URL ***********/
/*
 * open a bootstrap modal for ajax or inline contents
 * show_footer: boolean true/false, default false
 * title: title for the modal
 * content: content for the modal, this can be empty and use below attr
 * url: url for the ajax or iframe request and get the content for the modal
 * mode: inline/ajax/iframe
 * ajax_params: json with ajax params
 * modal_size: "modal-lg", "modal-sm", ""(default as normal "")
 * callback: function evaluated after modal shown
 * return modal object
 */
function open_modal(settings){
    var def = {title: "", content: null, url: null, show_footer: false, mode: "inline", ajax_params: {}, modal_size: "", modal_settings:{}, callback: function(){}}
    settings = $.extend({}, def, settings);
    var modal = $('<div id="ow_inline_modal" class="modal fade">'+
        '<div class="modal-dialog '+settings.modal_size+'">'+
        '<div class="modal-content">'+
        '<div class="modal-header">'+
        '<button type="button" class="close" data-dismiss="modal" aria-hidden="true">&times;</button>'+
        '<h4 class="modal-title">'+settings.title+'</h4>'+
        '</div>'+
        '<div class="modal-body"></div>'+
        (settings.show_footer?'<div class="modal-footer"><button type="button" class="btn btn-default" data-dismiss="modal">Close</button></div>':'')+
        '</div>'+
        '</div>'+
        '</div>');

    modal.on("hidden.bs.modal", function(e){ if(!$(e["currentTarget"]).attr("data-skip_destroy")) $(e["currentTarget"]).remove(); });
    modal.on("show.bs.modal", function(e){ settings.callback(modal); });
    if(settings.mode == "inline"){
        modal.find(".modal-body").html(settings.content);
        modal.modal(settings.modal_settings);
    }else if(settings.mode == "iframe"){
        modal.find(".modal-body").html('<iframe style="min-height: 500px;" src="'+settings.url+'" width="100%" frameborder=0></iframe>');
        modal.modal(settings.modal_settings);
    }else{ //ajax mode
        showLoading();
        $.get(settings.url, settings.ajax_params, function(res){
            modal.find(".modal-body").html(res);
            hideLoading()
            modal.modal(settings.modal_settings);
        });
    }
    return modal;
}

/**************LOADING SPINNER************/
/*
 * use:
 *      showLoading() for show the loading spinner
 *      hideLoading() for hide the loading spinner
 */
function wait_modal(){
    var modal;
    var html = '<div class="modal" id="pleaseWaitDialog" data-backdrop="static" data-keyboard="false"><div class="modal-dialog modal-sm"><div class="modal-content"><div class="modal-header"><h4 class="modal-title">Processing...</h4></div>'+
        '<div class="modal-body"><div class="progress"><div class="progress-bar progress-bar-striped active" role="progressbar" aria-valuenow="100" aria-valuemin="0" aria-valuemax="100" style="width: 100%"></div></div>'+
        '</div>'+
        '</div>'+
        '</div>'+
        '</div>';
    this.show = function(){
        if(!modal) modal = $(html);
        modal.modal("show");
    }
    this.hide = function(){
        if(!modal) modal = $(html);
        modal.modal("hide");
    }
}
var loading_modal = new wait_modal();
function showLoading(){ $("body > .modal").not("#pleaseWaitDialog").hide(); loading_modal.show(); }
function hideLoading(){ loading_modal.hide(); $("body > .modal").not("#pleaseWaitDialog").show(); }