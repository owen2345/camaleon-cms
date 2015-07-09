/**
 *
 // options:
     // - title: Title Modal, default: Upload File
     // - type: image, video, audio, application/pdf,... default: 'all'
     // - multiple: return array files or uniq file, default: false
    //  - mode, menubar icons visibility, default: basic,  values: full, basic
    // - params: in mode basic use options toolbar: default: [], example: ['resize','mkdir']
    // - tree: in mode basic use, default: false
 // callback: function called after imported the file on elfinder.

 sample:
 open_elfinder({title: "Modal de otras cosas", type: "image", multiple: true}, function(files){
        console.log(files);
        ==>
        // files (multiple: false): {name: "file.ext", url: "/media/url/file.ext", mime: "image/jpeg", size: 1024, dim: "500x383", date: "2015-04-24 11:45:57 -0400"}
        // files (multiple: true): [{name: "file.ext", url: "/media/url/file.ext", mime: "image/jpeg", size: 1024, dim: "500x383", date: "2015-04-24 11:45:57 -0400"},...{}]
    });

 Includes:
 option 1: load by javascript_include_tag("elfinder_front.js") or by manifest: require elfinder_front.js
 option 2: load by add_asset_library("elfinder_front")

 * Note: you need bootstrap + jquery to use this method or
 * choose any other modal box plugin to show the iframe and then add your arguments, don't forget the callback method like this:
 *  window.callback_modal_elfinder = function(data){ console.log(data); }  // this function is called from elfinder after imported
 */

function open_elfinder(options, callback){
    options = $.extend(options ? options : {}, {title: 'Upload File'});
    var modal = $('<div class="modal fade" id="el_finder_uploader">'+
    '<div class="modal-dialog" style="width: 90%; max-width: 1100px">'+
    '<div class="modal-content">'+
    '<div class="modal-header">'+
    '<button type="button" class="close" data-dismiss="modal" aria-hidden="true">&times;</button>'+
    '<h4 class="modal-title">' + options.title + '</h4>'+
    '</div>'+
    '<div class="modal-body overflow-visible" style="padding: 0">' +
        '<div id="elfinder_loading" style="max-width: 200px; z-index: 2; position: relative; margin: 100px auto -120px;" class="progress"><div class="progress-bar progress-bar-striped active" role="progressbar" aria-valuenow="100" aria-valuemin="0" aria-valuemax="100" style="width: 100%"></div></div>'+
        '<iframe frameborder="0" src="'+ROOT_URL+'/admin/elfinder/iframe?'+jQuery.param(options)+'" style="width: 100%; height: 462px; overflow: hidden; border: none;" />'+
    '</div>'+
    '</div>'+
    '</div>'+
    '</div>');

    modal.on("hidden.bs.modal", function(e){ $(e["currentTarget"]).remove(); });

    // close all modals
    $('#el_finder_uploader').modal('hide');
    // open modal
    modal.modal();

    window.callback_modal_elfinder = function(data){
        modal.modal('hide');
        if(typeof callback == "function") callback(data);
    }

    window.onload_modal_elfinder = function(){
        jQuery("#elfinder_loading").remove();
    }
}

jQuery(function($){
    $.fn.inline_uploader = function(options){
        var def = {no_image: ROOT_URL+"image-not-found.png", title: "File upload"};
        var settings = $.extend({}, def, options);
        $(this).each(function(){
            var input = $(this);
            var c = $("<span style='position: relative; cursor: pointer;'><img style='width: 50px; height: 30px; border: 1px solid #ccc;' class='thumb_uploader' src='"+(input.val() ? input.val() :settings.no_image)+"' /><i style='display: none; vertical-align: bottom' class='fa fa-times-circle btn_del'></i></span>");
            c.find(".btn_del").click(function(e){ $(this).prev().attr("src", settings.no_image); input.val("").trigger("change");e.stopPropagation(); return false; });
            c.click(function(){
                open_elfinder({title: settings.title, type: "image", multiple: false}, function(file){
                    c.find("img").attr("src", file.url);
                    input.val(file.url).trigger("change");
                });
            });
            input.change(function(){
                if(input.val()) c.find(".btn_del").show();
                else c.find(".btn_del").hide();
            });
            input.hide();
            input.before(c).trigger("change");
        });
    }
});
