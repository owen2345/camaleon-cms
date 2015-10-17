jQuery(function($){
    // initialize all validations for forms
    init_form_validations();
    setTimeout(page_actions, 1000);
    setTimeout(start_cama_ajax_requestor, 500);
    if(!$("body").attr("data-intro")) setTimeout(init_intro, 500);
});

// show admin intro presentation
function init_intro(){
    var finish = function(){
        $.get(root_url+"/admin/ajax", {mode: "save_intro"});
        var layer = $(".introjs-overlay").clone();
        var of = $(".introjs-tooltip").offset();
        var c = $(".introjs-tooltip").clone().css($.extend({}, {"min-width": "0", position: "absolute", overflow: "hidden", "zIndex": 9999999}, of));
        $("html, body").animate({scrollTop: $("body").height()}, 0);
        setTimeout(function(){
            $("body").append(layer, c);
            c.animate($.extend({}, {width: 75, height: 20}, $("#link_see_intro").offset()), "slow", function(){ setTimeout(function(){ c.remove(); layer.remove(); }, 500); });
        }, 5)
    }
    introJs().setOptions({exitOnEsc: false,
        exitOnOverlayClick: false,
        showStepNumbers: false,
        showBullets: false,
        disableInteraction: true
    }).oncomplete(finish).onexit(finish).onbeforechange(function(ele) {
        if($(ele).hasClass("treeview") && !$(ele).hasClass("active")) $(ele).children("a").click();
        if($(ele).is("li")){
            var tree = $(ele).closest("ul");
            if(!tree.hasClass("menu-open")) tree.prev("a").click();
        }
    }).start();
}

// basic and common actions
var page_actions = function(){
    // button actions
    $('#admin_content a[role="back"]').on('click',function(){ window.history.back(); return false; });
    $('a[data-toggle="tooltip"], button[data-toggle="tooltip"], a[title!=""]', "#admin_content").not(".skip_tooltip").tooltip();

    /* PANELS */
    $("#admin_content").on("click", ".panel .panel-collapse", function(){
        panel_collapse($(this).parents(".panel:first"));
        $(this).parents(".dropdown").removeClass("open");
        return false;
    });
}

/**
 * small camaleon ajax requester (alternative to turbolinks)
 * support for links and forms by adding the class: cama_ajax_request. Also you can add the class in a div to apply this for all inner links
 * data-before-callback: is an attribute where you can put the function name called before start request.
 *  Also this can return false to stop continuing
 * data-after-callback: is an attribute where you can put the function name called after request was completed
 * data-error-callback: is an attribute where you can put the function name called when a error occurred in the request
 */
function start_cama_ajax_requestor(){
    var do_ajax_request = function(){
        var link = $(this);
        var url = link.attr("href") || link.attr("action");
        if(!url || url == "#") return true;

        var before = link.attr("data-before-callback");
        var after = link.attr("data-after-callback");
        var error = link.attr("data-error-callback");
        var flag = true;
        if(before) flag = window[before](link);
        showLoading();
        $.get(url, {cama_ajax_request: true}, function(res){
            $("#admin_content").fadeTo(0, 0).html(res).fadeTo("normal", 1);
            if(after) window[after](link, res);
            hideLoading();
        }).error(function(e, status, msg){
            $.fn.alert({type: "error", content: msg});
            if(error) window[error](link, arguments);
        });
        return false;
    }
    $("body").on("submit", "form.cama_ajax_request", do_ajax_request);
    $("body").on("click", "a.cama_ajax_request, .cama_ajax_request:not(form) a", do_ajax_request);
}

// add action to toggle the collapse for panels
function panel_collapse(panel,action,callback){
    if(panel.hasClass("panel-toggled")){
        panel.removeClass("panel-toggled");
        panel.find(".panel-collapse .fa-angle-up").removeClass("fa-angle-up").addClass("fa-angle-down");
        if(action && action === "shown" && typeof callback === "function")
            callback();
    }else{
        panel.addClass("panel-toggled");
        panel.find(".panel-collapse .fa-angle-down").removeClass("fa-angle-down").addClass("fa-angle-up");
        if(action && action === "hidden" && typeof callback === "function")
            callback();
    }
}

/* PLAY SOUND FUNCTION */
function playAudio(file){
    if(file === 'alert')
        document.getElementById('audio-alert').play();

    if(file === 'fail')
        document.getElementById('audio-fail').play();
}

/* NEW OBJECT(GET SIZE OF ARRAY) */
Object.size = function(obj) {
    var size = 0, key;
    for (key in obj) {
        if (obj.hasOwnProperty(key)) size++;
    }
    return size;
};

// this is a fix for multiples modals when a modal was closed (reactivate scroll for next modal)
// fix for boostrap multiple modals problem
function modal_fix_multiple(){
    var activeModal = $('.modal.in:last', 'body').data('bs.modal');
    if (activeModal) {
        activeModal.$body.addClass('modal-open');
        activeModal.enforceFocus();
        activeModal.handleUpdate();
    }
}