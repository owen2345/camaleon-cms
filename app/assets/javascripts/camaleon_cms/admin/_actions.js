var onReadyOrChanged = function(){
    // Bind the AdminLTE sidebar tree at DOM ready. AdminLTE 2.4 only activates it on window.load,
    // so a click on an expandable parent before load would otherwise fall through its (now href="#")
    // anchor with no toggle. The Tree plugin guards against double-init, so the load-time Data API
    // becomes a no-op. (PR #1169 review.)
    if ($.fn.tree) $('[data-widget="tree"]').tree();
    // Restore AdminLTE 2.3's body-delegated Bootstrap tooltip: 2.4 dropped it, so a tooltip trigger
    // inserted later via AJAX (e.g. cama_contact_form's field rows) no longer got a tooltip. Bind
    // once, lazily, for every current and future [data-toggle="tooltip"]. Bootstrap reuses an
    // element's existing instance, so this does not double-init the ones page_actions eager-inits.
    if (!window.cama_tooltip_delegated) {
        window.cama_tooltip_delegated = true;
        $(document.body).tooltip({ selector: "[data-toggle='tooltip']:not(.skip_tooltip)", container: 'body' });
    }
    // initialize all validations for forms
    init_form_validations();
    setTimeout(page_actions, 1000);
    if(!$("body").attr("data-intro")) setTimeout(init_intro, 500);
};
jQuery(onReadyOrChanged);
jQuery(document).on("page:changed", onReadyOrChanged);

// show admin intro presentation
function init_intro(){
    var finish = function(){
        $.get(root_admin_url+"/ajax", {mode: "save_intro"});
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
        disableInteraction: true,
        buttonClass: 'btn'
    }).oncomplete(finish).onexit(finish).onbeforechange(function(ele) {
        cama_intro_reveal_menu(ele);
    }).start();
}

// Reveal the sidebar menu branch a given intro step lives in, so the highlighted item is visible.
// AdminLTE 2.4 marks the EXPANDED PARENT LI `menu-open` (2.3 marked the ul.treeview-menu), so the
// "is this submenu already open?" test must read the parent li -- reading the ul (as before) is
// always false under 2.4, which re-clicked the toggle and COLLAPSED the branch the step points at.
// (PR #1169 review.) Kept as a named function so the reveal logic is unit-testable.
function cama_intro_reveal_menu(ele){
    var $ele = $(ele);
    if($ele.hasClass("treeview") && !$ele.hasClass("active")) $ele.children("a").click();
    if($ele.is("li")){
        var tree = $ele.closest("ul");
        if(!tree.parent("li").hasClass("menu-open")) tree.prev("a").click();
    }
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
