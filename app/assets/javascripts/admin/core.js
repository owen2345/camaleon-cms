jQuery(function($){
    // init validates and translate render forms
    init_form_validations();

    $('#admin_content table').addClass('table').wrap('<div class="table-responsive"></div>');

    $('#admin_content a[role="back"]').on('click',function(){
        window.history.back();
        return false;
    });

    $('#admin_content [data-toggle="tooltip"]').tooltip();
    $('a.btn-xs, a.panel-edit, a.panel-delete, button.btn', "#admin_content").tooltip();

});

function log(d){
    if(console.log)console.log(d);
}


/****************** form validations ************/
// panel can be a object: $("#my_form")
// if panel is null, then this will be replaced by body
var init_form_validations = function(form){

    // slug management
    // you need to add class no_translate to avoid translations in slugs
    (form ? form : $('#admin_content')).find('input.slug').each(function(){
        var sl_id = $(this).attr("data-parent");
        if(!sl_id) return;
        var $parent = $('#'+sl_id);
        if($parent.hasClass('translated-item')){
            var $panel_parent = $parent.siblings('.trans_panel:first');
            if($(this).hasClass("no_translate")){
                $(this).slugify('#'+$panel_parent.find('.tab-content .tab-pane:first input:first').attr('id'));
            }else{
                $(this).addClass('translatable').Translatable(ADMIN_TRANSLATIONS);
                var $panel_slug = $(this).siblings('.trans_panel:first');
                $panel_parent.find('.tab-content .tab-pane').each(function(index, tab_pane){
                    var p_id = $(tab_pane).children('input').attr('id');
                    $panel_slug.find('.tab-content .tab-pane:eq('+index+') input:first').slugify('#'+p_id);
                })
                $panel_parent.find('.nav > li a').each(function(index, a_tab){
                    $(a_tab).click(function(){
                        $panel_slug.find('.nav > li:eq('+index+') a').click()
                    })
                })
            }
        }else{
            $(this).slugify('#'+sl_id);
        }
    });

    (form ? form : $('#admin_content form')).each(function () {
        var $form = $(this)
        if ($form.find('.translatable').size() > 0) {
            $form.find('.translatable').Translatable(ADMIN_TRANSLATIONS);
        }
    }).filter("[class^='validate']").each(function(){
        $(this).validate({ focusInvalid: true, ignore: ($(this).hasClass('input-all'))? '' : ':hidden', errorPlacement: function (a,b) {
            if(a.text()){
                if(b.parent().hasClass('form-group')){
                    b.parent().addClass('has-error').append(a.addClass('help-block'));
                }else if(b.parent().hasClass('tab-pane')){ // tabs
                    var parent = b.parent();
                    $("a[href='#"+ parent.attr('id') +"']").addClass('has-error').trigger('click');
                    parent.addClass('has-error').append(a.addClass('help-block'));
                }else{
                    b.parent().after(a.addClass('help-block')).parent().addClass('has-error');
                }
            }
        }, success: function(error, element){
            $(element).parent().removeClass('has-error').parent().removeClass('has-error')
            if($(element).parent().hasClass('tab-pane')) $("a[href='#"+ $(element).parent().attr('id') +"']").removeClass('has-error');
        } })
    });
};


!(function($){

    jQuery.fn.serializeObject=function() {
        var json = {};
        jQuery.map(jQuery(this).serializeArray(), function(n, i) {
            var __i = n.name.indexOf('[');
            if (__i > -1) {
                var o = json;
                _name = n.name.replace(/\]/gi, '').split('[');
                for (var i=0, len=_name.length; i<len; i++) {
                    if (i == len-1) {
                        if (o[_name[i]] && $.trim(_name[i]) == '') {
                            if (typeof o[_name[i]] == 'string') {
                                o[_name[i]] = [o[_name[i]]];
                            }
                            o[_name[i]].push(n.value);
                        }
                        else o[_name[i]] = n.value || '';
                    }
                    else o = o[_name[i]] = o[_name[i]] || {};
                }
            }
            else {
                if (json[n.name] !== undefined) {
                    if (!json[n.name].push) {
                        json[n.name] = [json[n.name]];
                    }
                    json[n.name].push(n.value || '');
                }
                else json[n.name] = n.value || '';
            }
        });
        return json;
    };

    $.fn.alert = function (options) {
        var default_options = {title: lang.message_updated_success, content: "", type: "success", icon: "check", close: "Close"};
        options = $.extend(default_options, options || {});

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
})(jQuery);


(function($){
    $.fn.input_upload = function (options_init) {
        var default_options = {label: lang.upload_image, type: "image", ext: "none", icon: "upload", full_url: true, height: '100px'};
        default_options = $.extend({}, default_options, options_init || {});
        $(this).each(function(){
            var $that = $(this);
            var options = $.extend({}, default_options, $that.data() || {});
            var $content_image = $("<div class='content-upload-plugin'><a href='#' target='_blank'><img src=''><strong></strong></a></div>").hide();
            if(options.type != 'image') $content_image.find('img').remove();
            var $btn_upload = $('<a class="btn btn-default" href="#"><i class="fa fa-upload"></i> '+options.label+'</a>')
            $content_image.find('img').css('max-height', options.height);

            $btn_upload.click(function(){
                $.fn.upload_elfinder({
                    selected: function(res){
                        var image = _.first(res);
                        if(options.type == 'all' || (image.mime && image.mime.indexOf(options.type) > -1) || _.last(image.name.split(".")) == options.ext){
                            set_texts(options.full_url ? image.url.to_url() :image.url)
                        }else{
                            alert("File extension not allowed")
                        }
                    }
                });
                return false;
            });

            $that.after($content_image).after($btn_upload);

            function set_texts(url){
                $content_image.find('img').attr('src', url);
                $content_image.find('a').attr('href', url);
                $that.val(url);
                $content_image.find('strong').html(_.last(url.split('/')));
                $content_image.show()
            }

            if($that.val()) set_texts($that.val())

        });


    };
})(jQuery);

// helper validate only letters latin
(function($){
    var regex = /^[a-z\sÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏàáâãäåæçèéêëìíîïÐÑÒÓÔÕÖØÙÚÛÜÝÞßðñòóôõöøùúûüýþÿ]+$/i;
    jQuery.validator.addMethod("lettersonly", function(value, element) {
        return this.optional(element) || regex.test(value);
    }, "Only alphabetical characters");
})(jQuery);

(function($){
    $.fn.table_order = function (options){
        var default_options = {url: "", table: ".table", on_success: false, on_change: false};
        options = $.extend(default_options, options || {});
        var th_data = false;
        var $table = this ? $(this) : $(options.table);
        $table.addClass('table_order')
        var th_new = '<th class="center" data-sortable="0"></th>';
        $table.find('thead tr').prepend(th_new);
        $table.find('tbody tr').each(function(i, el) {
            var id = $(this).attr('data-id');
            var td_new = '<td>'
                +'<div class="moved" style="cursor: all-scroll">'
                +'<i class="fa fa-arrows"></i>'
                +'<input type="hidden" name="values[]" value="'+id+'" />'
                +'</div>'
            '</td>';
            $(this).prepend(td_new);
        });

        $table.find('tbody').sortable({
            axis: "y",
            placeholder: "ui-state-highlight",
            handle: ".moved",
            //items: "tr:not(.sortable)",
            items: "tr",
            start: function(event, ui) {
                ui.item.startPos = ui.item.index();
            },
            stop: function( event, ui ) {
                $.post(options.url, $table.find("input" ).serialize(), function(res){
                    if(ui.item.startPos != ui.item.index()){
                        if(options.on_success) options.on_success({res: res, item: ui.item})
                    }
                }).fail(function() {
                    if(options.on_success) options.on_success({res: {error: 'Error Server'}, item: ui.item})
                });
            },
            change: function(event, ui) {
                if(options.on_change) options.on_change()
            }
        });
        $table.find('tbody').disableSelection();
    };

})(jQuery);

String.prototype.hashCode = function() {
    var message = this;
    if(message == "") {
        return "";
    }
    var chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/_-".split("");
    var length = 40;
    for(var last = 0, i = 0, len = message.length; i < len; i++) {
        last = (message.charCodeAt(i) + 31 * last) % 59;
    }
    length = length || message.length;
    while(len < length) {
        message += message;
        len += len;
    }
    message = message.slice(0, length);
    for(var ret = "", i = 0; i < length; i++) {
        ret += chars[last = (i + last + message.charCodeAt(i)) % 64];
    }
    return ret;
};

!function(a){"function"==typeof define&&define.amd?define(["jquery"],function(b){a(b)}):"object"==typeof module&&"object"==typeof module.exports?module.exports=a(require("jquery")):a(window.jQuery)}(function(a){"use strict";function b(a){void 0===a&&(a=window.navigator.userAgent),a=a.toLowerCase();var b=/(edge)\/([\w.]+)/.exec(a)||/(opr)[\/]([\w.]+)/.exec(a)||/(chrome)[ \/]([\w.]+)/.exec(a)||/(version)(applewebkit)[ \/]([\w.]+).*(safari)[ \/]([\w.]+)/.exec(a)||/(webkit)[ \/]([\w.]+).*(version)[ \/]([\w.]+).*(safari)[ \/]([\w.]+)/.exec(a)||/(webkit)[ \/]([\w.]+)/.exec(a)||/(opera)(?:.*version|)[ \/]([\w.]+)/.exec(a)||/(msie) ([\w.]+)/.exec(a)||a.indexOf("trident")>=0&&/(rv)(?::| )([\w.]+)/.exec(a)||a.indexOf("compatible")<0&&/(mozilla)(?:.*? rv:([\w.]+)|)/.exec(a)||[],c=/(ipad)/.exec(a)||/(ipod)/.exec(a)||/(iphone)/.exec(a)||/(kindle)/.exec(a)||/(silk)/.exec(a)||/(android)/.exec(a)||/(windows phone)/.exec(a)||/(win)/.exec(a)||/(mac)/.exec(a)||/(linux)/.exec(a)||/(cros)/.exec(a)||/(playbook)/.exec(a)||/(bb)/.exec(a)||/(blackberry)/.exec(a)||[],d={},e={browser:b[5]||b[3]||b[1]||"",version:b[2]||b[4]||"0",versionNumber:b[4]||b[2]||"0",platform:c[0]||""};if(e.browser&&(d[e.browser]=!0,d.version=e.version,d.versionNumber=parseInt(e.versionNumber,10)),e.platform&&(d[e.platform]=!0),(d.android||d.bb||d.blackberry||d.ipad||d.iphone||d.ipod||d.kindle||d.playbook||d.silk||d["windows phone"])&&(d.mobile=!0),(d.cros||d.mac||d.linux||d.win)&&(d.desktop=!0),(d.chrome||d.opr||d.safari)&&(d.webkit=!0),d.rv||d.edge){var f="msie";e.browser=f,d[f]=!0}if(d.safari&&d.blackberry){var g="blackberry";e.browser=g,d[g]=!0}if(d.safari&&d.playbook){var h="playbook";e.browser=h,d[h]=!0}if(d.bb){var i="blackberry";e.browser=i,d[i]=!0}if(d.opr){var j="opera";e.browser=j,d[j]=!0}if(d.safari&&d.android){var k="android";e.browser=k,d[k]=!0}if(d.safari&&d.kindle){var l="kindle";e.browser=l,d[l]=!0}if(d.safari&&d.silk){var m="silk";e.browser=m,d[m]=!0}return d.name=e.browser,d.platform=e.platform,d}return window.jQBrowser=b(window.navigator.userAgent),window.jQBrowser.uaMatch=b,a&&(a.browser=window.jQBrowser),window.jQBrowser});