
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
            if($(this).attr('data-modal_size')) def["modal_size"] = $(this).attr('data-modal_size');
            var c_settings = $.extend({}, def, settings);
            open_modal(c_settings);
            e.preventDefault();
        });
        return this;
    }

    // custom alert dialog
    // show a custom modal box with messages
    // sample: $.fn.alert({type: 'error', content: 'My error', title: "My Title"})
    // type: error | warning | success
    $.fn.alert = function (options) {
        hideLoading();
        var default_options = {title: I18n("msg.updated_success"), type: "success", zindex: '99999999', id: 'cama_alert_modal' };
        options = $.extend(default_options, options || {});
        if(options.type == "error") options.type = "danger";
        if(options.type == "alert") options.type = "warning";
        if(!options.content){
            options.content = options.title
            options.title = "";
        }
        open_modal(options);
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
 * on_close: function executed after modal closed
 * return modal object
 */
function open_modal(settings){
    var def = {title: "", content: null, url: null, show_footer: false, mode: "inline", ajax_params: {}, id: 'ow_inline_modal', zindex: null, modal_size: "", type: '', modal_settings:{}, on_submit: null, callback: function(){}, on_close: function(){}}
    settings = $.extend({}, def, settings);
    if(settings.id){
        var hidden_modal = $("#"+settings.id);
        if(hidden_modal.size()){ hidden_modal.modal('show'); return hidden_modal; }
    }
    var modal = $('<div id="'+settings.id+'" class="modal fade modal-'+settings.type+'">'+
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
        settings.on_close(modal);
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
        modal.find(".modal-body").html('<iframe id="ow_inline_modal_iframe" style="min-height: 500px;" src="'+settings.url+'" width="100%" frameborder=0></iframe>');
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
function showLoading(){ $.fn.customLoading("show"); }
function hideLoading(){ $.fn.customLoading("hide"); }
jQuery(function(){
    /**
     * params:
     *  percentage: integer (percentage of the progress)
     *  state: String (show | hide)
     * Sample:
     *  $.fn.customLoading("show"); // show loading
     *  $.fn.customLoading("hide"); // hide de loading
     */
    $.fn.customLoading2 = function(params){
        if(!params) params = "show";
        if(typeof params == "string") params = {state: params};
        var settings = $.extend({}, {percentage: 100, state: "show"}, params);
        if(settings.state == "show"){
            if($("body > #custom_loading").length == 0)
                $("body").append('<div id="custom_loading" style="position: fixed; z-index: 99999; width: 100%; top: 0px; height: 15px;" class="progress"><div class="progress-bar progress-bar-striped active progress-bar-success" role="progressbar" aria-valuenow="45" aria-valuemin="0" aria-valuemax="100" style="width: '+settings.percentage+'%;"><span class="sr-only">45% Complete</span></div></div>');
            else
                $("body > #custom_loading").width(settings.percentage);
        }else{
            $("body > #custom_loading").remove();
        }
    }

    $.fn.customLoading = function(params){
        if(!params) params = "show";
        if(typeof params == "string") params = {state: params};
        var settings = $.extend({}, {percentage: 100, state: "show"}, params);
        if(settings.state == "show"){
            if($("body > #cama_custom_loading").length == 0)
                $("body").append('<div id="cama_custom_loading"><div class="back_spinner"></div><div class="loader_spinner"></div></div>');
            else
                $("body > #cama_custom_loading").width(settings.percentage);
        }else{
            $("body > #cama_custom_loading").remove();
        }
    }
});
