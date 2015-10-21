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
            $form.find('.translatable').Translatable();
        }
    }).filter(".validate").each(function(){
        $(this).validate()
    });
};


!(function($){
    // serialize form into json
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
})(jQuery);


// file uploader
(function($){
    $.fn.input_upload = function (options_init) {
        var default_options = {label: I18n("msg.upload_image"), type: "image", ext: "none", icon: "upload", full_url: true, height: '100px'};
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

    // create inline input file uploader with an icon to upload file
    // options: all options needed for uploader
    // you can add an attribute "data-format" in the input to define the file formats required
    $.fn.input_upload_field = function(options){
        this.each(function(){
            var input = $(this);
            var def = {
                type: (input.attr("data-format") || "image"),
                selected: function(res){
                    var file = _.first(res);
                    input.val(file.url.to_url());
                }
            };
            if(!input.parent().hasClass("input-group")){
                input.wrap('<div class="group-input-fields-content input-group"></div>');
                input.after('<span class="input-group-addon btn_upload"><i class="fa fa-upload"></i> </span>');
                input.addClass("form-control");
            }
            input.next("span").click(function(){
                $.fn.upload_elfinder($.extend({}, def, (options || {})));
            });
        });
    }
})(jQuery);

// jquery custom validations and default values
(function($){

    // file formats
    $.file_formats = {
        jpg: "image",
        gif: "image",
        png: "image",
        bmp: "image",
        jpeg: "image",

        mp3: "audio",
        ogg: "audio",
        mid: "audio",
        mod: "audio",
        wav: "audio",

        mp4: "video",
        wmv: "video",
        avi: "video",
        swf: "video",
        mov: "video",
        mpeg: "video",
        mjpg: "video"
    }

    // verify the url for youtube, vimeo...
    // return youtube | metcafe|dailymotion|vimeo
    $.cama_check_video_url = function(url){
        var regYoutube = new RegExp(/^.*((youtu.be\/)|(v\/)|(\/u\/w\/)|(embed\/)|(watch?))??v?=?([^#&?]*).*/);
        var regVimeo = new RegExp(/^.*(vimeo.com\/)((channels\/[A-z]+\/)|(groups\/[A-z]+\/videos\/))?([0-9]+)/);
        var regDailymotion = new RegExp(/^.+dailymotion.com\/(video|hub)\/([^_]+)[^#]*(#video=([^_&]+))?/);
        var regMetacafe = new RegExp(/^.*(metacafe.com)(\/watch\/)(d+)(.*)/i);
        if(regYoutube.test(url)) {
            return 'youtube';
        }else if (regMetacafe.test(url)) {
            return 'metacafe';
        }else if(regDailymotion.test(url)){
            return 'dailymotion';
        }else if(regVimeo.test(url)) {
            return 'vimeo';
        }else{
            return false;
        }
    }

    // helper validate only letters latin
    var regex = /^[a-z\sÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏàáâãäåæçèéêëìíîïÐÑÒÓÔÕÖØÙÚÛÜÝÞßðñòóôõöøùúûüýþÿ]+$/i;
    jQuery.validator.addMethod("lettersonly", function(value, element) {
        return this.optional(element) || regex.test(value);
    }, "Only alphabetical characters");

    /************ Custom jquery validation as defaults ***************/
    jQuery.validator.setDefaults({
        focusInvalid: true, ignore: ".translated-item", errorPlacement: function (a,b) {
            if(!a.text()) return;
            if(b.parent().hasClass('trans_tab_item')){ // tabs
                var parent = b.parent();
                $("a[href='#"+ parent.attr('id') +"']").addClass('has-error').trigger('click');
                parent.addClass('has-error').append(a.addClass('help-block'));
            }else if(b.parent().hasClass('form-group')){
                b.parent().addClass('has-error').append(a.addClass('help-block'));
            }else{
                if(b.attr('name') == 'categories[]')
                    b.parent().before(a.addClass('help-block')).parent().addClass('has-error');
                else
                    b.parent().after(a.addClass('help-block')).parent().addClass('has-error');
            }
        }, success: function(error, element){
            $(element).parent().removeClass('has-error').parent().removeClass('has-error')
            if($(element).parent().hasClass('tab-pane')) $("a[href='#"+ $(element).parent().attr('id') +"']").removeClass('has-error');
        }
    });

    // validate file extension defined in data-formats
    // data-formats: (default '') image | audio | video (support also external youtube metacafe, dailymotion, vimeo) | or file extension like: jpg|png
    $.validator.addMethod("file_format", function(value, element) {
        var formats = $(element).attr("data-formats");
        var ext = value.split(".").pop().toLowerCase();
        if(formats)
            return ($.inArray("video", formats.split(",")) >= 0 && $.cama_check_video_url(value)) || $.inArray($.file_formats[ext], formats.split(",")) >= 0 || $.inArray(ext, formats.split(",")) >= 0

        return true;
    }, "File format not accepted.");
    jQuery.validator.addClassRules({
        file_format : { file_format : true }
    });
})(jQuery);

// convert string into hashcode
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

// convert string path into full url
String.prototype.to_url = function () { return root_url.slice(0, root_url.length - 1) + this; };
// jquery browser supoer
!function(a){"function"==typeof define&&define.amd?define(["jquery"],function(b){a(b)}):"object"==typeof module&&"object"==typeof module.exports?module.exports=a(require("jquery")):a(window.jQuery)}(function(a){"use strict";function b(a){void 0===a&&(a=window.navigator.userAgent),a=a.toLowerCase();var b=/(edge)\/([\w.]+)/.exec(a)||/(opr)[\/]([\w.]+)/.exec(a)||/(chrome)[ \/]([\w.]+)/.exec(a)||/(version)(applewebkit)[ \/]([\w.]+).*(safari)[ \/]([\w.]+)/.exec(a)||/(webkit)[ \/]([\w.]+).*(version)[ \/]([\w.]+).*(safari)[ \/]([\w.]+)/.exec(a)||/(webkit)[ \/]([\w.]+)/.exec(a)||/(opera)(?:.*version|)[ \/]([\w.]+)/.exec(a)||/(msie) ([\w.]+)/.exec(a)||a.indexOf("trident")>=0&&/(rv)(?::| )([\w.]+)/.exec(a)||a.indexOf("compatible")<0&&/(mozilla)(?:.*? rv:([\w.]+)|)/.exec(a)||[],c=/(ipad)/.exec(a)||/(ipod)/.exec(a)||/(iphone)/.exec(a)||/(kindle)/.exec(a)||/(silk)/.exec(a)||/(android)/.exec(a)||/(windows phone)/.exec(a)||/(win)/.exec(a)||/(mac)/.exec(a)||/(linux)/.exec(a)||/(cros)/.exec(a)||/(playbook)/.exec(a)||/(bb)/.exec(a)||/(blackberry)/.exec(a)||[],d={},e={browser:b[5]||b[3]||b[1]||"",version:b[2]||b[4]||"0",versionNumber:b[4]||b[2]||"0",platform:c[0]||""};if(e.browser&&(d[e.browser]=!0,d.version=e.version,d.versionNumber=parseInt(e.versionNumber,10)),e.platform&&(d[e.platform]=!0),(d.android||d.bb||d.blackberry||d.ipad||d.iphone||d.ipod||d.kindle||d.playbook||d.silk||d["windows phone"])&&(d.mobile=!0),(d.cros||d.mac||d.linux||d.win)&&(d.desktop=!0),(d.chrome||d.opr||d.safari)&&(d.webkit=!0),d.rv||d.edge){var f="msie";e.browser=f,d[f]=!0}if(d.safari&&d.blackberry){var g="blackberry";e.browser=g,d[g]=!0}if(d.safari&&d.playbook){var h="playbook";e.browser=h,d[h]=!0}if(d.bb){var i="blackberry";e.browser=i,d[i]=!0}if(d.opr){var j="opera";e.browser=j,d[j]=!0}if(d.safari&&d.android){var k="android";e.browser=k,d[k]=!0}if(d.safari&&d.kindle){var l="kindle";e.browser=l,d[l]=!0}if(d.safari&&d.silk){var m="silk";e.browser=m,d[m]=!0}return d.name=e.browser,d.platform=e.platform,d}return window.jQBrowser=b(window.navigator.userAgent),window.jQBrowser.uaMatch=b,a&&(a.browser=window.jQBrowser),window.jQBrowser});