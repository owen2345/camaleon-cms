function log(d) {
    if (console.log)console.log(d);
}

// prepend flash message into current element
// message: text message
// kind: string kind of message, default danger (success, danger, info, warning)
// sample: $("my_ele").flash_message("updated", "success");
jQuery(function(){
    $.fn.flash_message = function(message, kind){
        if(!kind) kind = !message ? "success" : "danger";
        if(!message) message = I18n("msg.success_action", "Action completed successfully.");
        var msg = '<div class="alert alert-'+kind+'"> <button type="button" class="close" data-dismiss="alert" aria-label="Close"><span aria-hidden="true">&times;</span></button> '+message+' </div>';
        $(this).prepend(msg);
        return this;
    }
});

/****************** form validations ************/
// panel can be a object: $("#my_form")
// if panel is null, then this will be replaced by body
    // args: {validate_settings}
var init_form_validations = function (form, args) {
    args = args || {};
    // slug management
    // you need to add class no_translate to avoid translations in slugs
    (form ? form : $('#admin_content')).find('input.slug').each(function () {
        var sl_id = $(this).attr("data-parent");
        if (!sl_id) return;
        var $parent = $('#' + sl_id);
        if ($parent.hasClass('translated-item')) {
            var $panel_parent = $parent.siblings('.trans_panel:first');
            if ($(this).hasClass("no_translate")) {
                $(this).slugify('#' + $panel_parent.find('.tab-content .tab-pane:first input:first').attr('id'));
            } else {
                $(this).addClass('translatable').Translatable(ADMIN_TRANSLATIONS);
                var $panel_slug = $(this).siblings('.trans_panel:first');
                $panel_parent.find('.tab-content .tab-pane').each(function (index, tab_pane) {
                    var p_id = $(tab_pane).children('input').attr('id');
                    $panel_slug.find('.tab-content .tab-pane:eq(' + index + ') input:first').slugify('#' + p_id);
                })
                $panel_parent.find('.nav > li a').each(function (index, a_tab) {
                    $(a_tab).click(function () {
                        $panel_slug.find('.nav > li:eq(' + index + ') a').click()
                    })
                })
            }
        } else {
            $(this).slugify('#' + sl_id);
        }
    });

    (form ? form : $('#admin_content form')).each(function () {
        var $form = $(this)
        if ($form.find('.translatable').size() > 0) {
            $form.find('.translatable').Translatable();
        }
    }).filter(".validate").each(function () {
        $(this).validate(args['validate_settings'])
    });
};

// file uploader
(function ($) {
    // sample: <input name="icon" class="upload_input" type="hidden" data-dimension="23x22" value="current_image_url"/>
    //          $(".upload_input").input_upload({label: '', title: 'Select Images', type: 'image', dimension: '30x30'});
    $.fn.input_upload = function (options_init) {
        var default_options = {label: I18n("msg.upload_image"), type: "image", ext: "none", icon: "upload", full_url: true, height: '100px'};
        default_options = $.extend({}, default_options, options_init || {});
        $(this).each(function () {
            var $that = $(this);
            var options = $.extend({}, default_options, $that.data() || {});
            var $content_image = $("<div class='content-upload-plugin'><a style='' href='#' target='_blank'><img src=''><br><span class='rm-file btn btn-xs btn-danger'><i class='fa fa-trash'></i></span></a></div>").hide();
            if (options.type != 'image') $content_image.find('img').remove();
            var $btn_upload = $('<a class="btn btn-default" href="#"><i class="fa fa-upload"></i> ' + options.label + '</a>')
            $content_image.find('img').css('max-height', options.height);
            $content_image.find(".rm-file").click(function(){ $that.val("").trigger("change"); return false; });

            $btn_upload.click(function(){
                $.fn.upload_filemanager({
                    formats: options.type,
                    selected: function (file, response) {
                        $that.val(file.url).trigger("change");
                    },
                    dimension: $that.attr('data-dimension') || options["dimension"],
                    versions: $that.attr('data-versions') || options["versions"],
                    thumb_size: $that.attr('data-thumb_size') || options["thumb_size"],
                    title: $that.attr('title') || options["title"],
                });
                return false;
            });

            $that.after($content_image).after($btn_upload);
            $that.change(function(){
                var url = $that.val();
                if(url){
                    $content_image.find('img').attr('src', url);
                    $content_image.find('a').attr('href', url);
                    //$content_image.find('strong').html(_.last(url.split('/')));
                    $content_image.show();
                }else{
                    $content_image.hide();
                }
            }).trigger("change");
        });
    };

    // create inline input file uploader with an icon to upload file
    // options: all options needed for uploader
    // you can add an attribute "data-format" in the input to define the file formats required
    $.fn.input_upload_field = function (options) {
        this.each(function () {
            var input = $(this);
            var def = {
                formats: (input.attr("data-format") || "image"),
                selected: function (file) {
                    input.val(file.url);
                }
            };
            if (!input.parent().hasClass("input-group")) {
                input.wrap('<div class="group-input-fields-content input-group"></div>');
                input.after('<span class="input-group-addon btn_upload"><i class="fa fa-upload"></i> </span>');
                input.addClass("form-control");
            }
            input.next("span").click(function () {
                $.fn.upload_filemanager($.extend({}, def, (options || {})));
            });
        });
    }
})(jQuery);

// serialize form into json
!(function ($) { jQuery.fn.serializeObject = function () { var json = {}; jQuery.map(jQuery(this).serializeArray(), function (n, i) { var __i = n.name.indexOf('['); if (__i > -1) { var o = json; _name = n.name.replace(/\]/gi, '').split('['); for (var i = 0, len = _name.length; i < len; i++) { if (i == len - 1) { if (o[_name[i]] && $.trim(_name[i]) == '') { if (typeof o[_name[i]] == 'string') { o[_name[i]] = [o[_name[i]]]; } o[_name[i]].push(n.value); } else o[_name[i]] = n.value || ''; } else o = o[_name[i]] = o[_name[i]] || {}; } } else { if (json[n.name] !== undefined) { if (!json[n.name].push) { json[n.name] = [json[n.name]]; } json[n.name].push(n.value || ''); } else json[n.name] = n.value || ''; } }); return json; }; })(jQuery);

// jquery browser support
!function (a) { "function" == typeof define && define.amd ? define(["jquery"], function (b) { a(b) }) : "object" == typeof module && "object" == typeof module.exports ? module.exports = a(require("jquery")) : a(window.jQuery) }(function (a) { "use strict"; function b(a) { void 0 === a && (a = window.navigator.userAgent), a = a.toLowerCase(); var b = /(edge)\/([\w.]+)/.exec(a) || /(opr)[\/]([\w.]+)/.exec(a) || /(chrome)[ \/]([\w.]+)/.exec(a) || /(version)(applewebkit)[ \/]([\w.]+).*(safari)[ \/]([\w.]+)/.exec(a) || /(webkit)[ \/]([\w.]+).*(version)[ \/]([\w.]+).*(safari)[ \/]([\w.]+)/.exec(a) || /(webkit)[ \/]([\w.]+)/.exec(a) || /(opera)(?:.*version|)[ \/]([\w.]+)/.exec(a) || /(msie) ([\w.]+)/.exec(a) || a.indexOf("trident") >= 0 && /(rv)(?::| )([\w.]+)/.exec(a) || a.indexOf("compatible") < 0 && /(mozilla)(?:.*? rv:([\w.]+)|)/.exec(a) || [], c = /(ipad)/.exec(a) || /(ipod)/.exec(a) || /(iphone)/.exec(a) || /(kindle)/.exec(a) || /(silk)/.exec(a) || /(android)/.exec(a) || /(windows phone)/.exec(a) || /(win)/.exec(a) || /(mac)/.exec(a) || /(linux)/.exec(a) || /(cros)/.exec(a) || /(playbook)/.exec(a) || /(bb)/.exec(a) || /(blackberry)/.exec(a) || [], d = {}, e = { browser: b[5] || b[3] || b[1] || "", version: b[2] || b[4] || "0", versionNumber: b[4] || b[2] || "0", platform: c[0] || ""}; if (e.browser && (d[e.browser] = !0, d.version = e.version, d.versionNumber = parseInt(e.versionNumber, 10)), e.platform && (d[e.platform] = !0), (d.android || d.bb || d.blackberry || d.ipad || d.iphone || d.ipod || d.kindle || d.playbook || d.silk || d["windows phone"]) && (d.mobile = !0), (d.cros || d.mac || d.linux || d.win) && (d.desktop = !0), (d.chrome || d.opr || d.safari) && (d.webkit = !0), d.rv || d.edge) { var f = "msie"; e.browser = f, d[f] = !0 } if (d.safari && d.blackberry) { var g = "blackberry"; e.browser = g, d[g] = !0 } if (d.safari && d.playbook) { var h = "playbook"; e.browser = h, d[h] = !0 } if (d.bb) { var i = "blackberry"; e.browser = i, d[i] = !0 } if (d.opr) { var j = "opera"; e.browser = j, d[j] = !0 } if (d.safari && d.android) { var k = "android"; e.browser = k, d[k] = !0 } if (d.safari && d.kindle) { var l = "kindle"; e.browser = l, d[l] = !0 } if (d.safari && d.silk) { var m = "silk"; e.browser = m, d[m] = !0 } return d.name = e.browser, d.platform = e.platform, d } return window.jQBrowser = b(window.navigator.userAgent), window.jQBrowser.uaMatch = b, a && (a.browser = window.jQBrowser), window.jQBrowser });
