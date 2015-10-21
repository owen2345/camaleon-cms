
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

    // custom alert dialog
    $.fn.alert = function (options) {
        hideLoading();
        var default_options = {title: I18n("msg.updated_success"), content: "", type: "success" };
        options = $.extend(default_options, options || {});
        if(options.type == "error") options.type = "danger";
        if(options.type == "alert") options.type = "warning";
        if(!options.content){
            options.content = options.title
            options.title = "";
        }
        open_modal(options);
        return;



        if (options.type == "error") options.type = "danger";
        if (options.type == "alert") options.type = "warning";

        var html = '<div class="message-box message-box-'+options.type+' animated fadeIn open" >'+
            '<div class="mb-container">'+
            '<div class="mb-middle">'+
            '<div class="mb-title"><span class="fa fa-'+options.icon+'"></span> '+options.title+'</div>'  +
            '<div class="mb-content">'+
            options.content+
            '</div>'+
            '<div class="mb-footer">'+
            '<button class="btn btn-default btn-lg pull-right mb-control-close">'+options.close+'</button>'+
            '</div>'+
            '</div>' +
            '</div>' +
            '</div>' ;

        if(options.type === 'warning')
            playAudio('alert');

        if(options.type === 'danger')
            playAudio('fail');

        var $html = $(html);
        $html.find('.mb-control-close').click(function(){
            $html.remove();
            return false;
        })
        $('body').append($html);

    };
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
 * type: modal color (primary|default|success)
 * zindex: Integer zindex position (default null)
 * on_submit: Function executed after submit button click (if this is present, enable the submit button beside cancel button)
 * return modal object
 */
function open_modal(settings){
    var def = {title: "", content: null, url: null, show_footer: false, mode: "inline", ajax_params: {}, zindex: null, modal_size: "", type: '', modal_settings:{}, on_submit: null, callback: function(){}}
    settings = $.extend({}, def, settings);
    var modal = $('<div id="ow_inline_modal" class="modal fade modal-'+settings.type+'">'+
        '<div class="modal-dialog '+settings.modal_size+'">'+
        '<div class="modal-content">'+
        '<div class="modal-header">'+
        '<button type="button" class="close" data-dismiss="modal" aria-hidden="true">&times;</button>'+
        '<h4 class="modal-title">'+settings.title+'</h4>'+
        '</div>'+
        '<div class="modal-body"></div>'+
        ((settings.show_footer || settings.on_submit)?'<div class="modal-footer"> '+(settings.on_submit ? '<button type="button" class="btn btn-primary modal_submit" ><i class="fa fa-save"></i> '+I18n("button.save")+'</button>' : '')+' <button type="button" class="btn btn-default" data-dismiss="modal"><i class="fa fa-arrow-circle-down"></i> '+I18n("button.close")+'</button></div>':'')+
        '</div>'+
        '</div>'+
        '</div>');

    // on modal hide
    modal.on("hidden.bs.modal", function(e){
        if(!$(e["currentTarget"]).attr("data-skip_destroy")) $(e["currentTarget"]).remove();
        modal_fix_multiple();
    });

    if(settings.zindex) modal.css("z-index", settings.zindex);

    // submit button
    if(settings.on_submit) modal.find(".modal-footer .modal_submit").click(function(){
        settings.on_submit(modal);
    });

    // on modal show
    modal.on("show.bs.modal", function(e){
        if(!modal.find(".modal-title").text()) modal.find(".modal-header .close").css("margin-top", "-9px");
        settings.callback(modal);
    });

    // show modal
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
