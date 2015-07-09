var page_actions = function(){
    /* MESSAGE BOX */
    $("#admin_logout").on("click",function(){
        var box = $($(this).data("box"));
        if(box.length > 0){
            box.toggleClass("open");
            var sound = box.data("sound");
            if(sound === 'alert')  playAudio('alert');
            if(sound === 'fail') playAudio('fail');
        }
        return false;
    });

    $("#mb-signout .mb-control-close").on("click",function(){
        $(this).parents(".message-box").removeClass("open");
        return false;
    });
    /* END MESSAGE BOX */

    /* PANELS */
    $("#admin_content .panel")/*.on("click", ".panel-fullscreen", function(){
        panel_fullscreen($(this).parents(".panel"));
        return false;
    })*/.on("click", ".panel-collapse", function(){
        panel_collapse($(this).parents(".panel:first"));
        $(this).parents(".dropdown").removeClass("open");
        return false;
    }).on("click", ".panel-remove",function(){
        panel_remove($(this).parents(".panel"));
        $(this).parents(".dropdown").removeClass("open");
        return false;
    }).on("click", ".panel-refresh",function(){
        var panel = $(this).parents(".panel");
        panel_refresh(panel);
        setTimeout(function(){ panel_refresh(panel); },3000);

        $(this).parents(".dropdown").removeClass("open");
        return false;
    });
    /* EOF PANELS */

    x_navigation();
}

jQuery(function($){
    setTimeout(page_actions, 1000);
    x_navigation_onresize();
    $(window).resize(function(){ x_navigation_onresize(); });
});


/* PANEL FUNCTIONS */
function panel_fullscreen(panel){

    if(panel.hasClass("panel-fullscreened")){
        panel.removeClass("panel-fullscreened").unwrap();
        panel.find(".panel-body,.chart-holder").css("height","");
        panel.find(".panel-fullscreen .fa").removeClass("fa-compress").addClass("fa-expand");

        $(window).resize();
    }else{
        var head    = panel.find(".panel-heading");
        var body    = panel.find(".panel-body");
        var footer  = panel.find(".panel-footer");
        var hplus   = 30;

        if(body.hasClass("panel-body-table") || body.hasClass("padding-0")){
            hplus = 0;
        }
        if(head.length > 0){
            hplus += head.height()+21;
        }
        if(footer.length > 0){
            hplus += footer.height()+21;
        }

        panel.find(".panel-body,.chart-holder").height($(window).height() - hplus);


        panel.addClass("panel-fullscreened").wrap('<div class="panel-fullscreen-wrap"></div>');
        panel.find(".panel-fullscreen .fa").removeClass("fa-expand").addClass("fa-compress");

        $(window).resize();
    }
}

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

function panel_refresh(panel,action,callback){
    if(!panel.hasClass("panel-refreshing")){
        panel.append('<div class="panel-refresh-layer"><img src="img/loaders/default.gif"/></div>');
        panel.find(".panel-refresh-layer").width(panel.width()).height(panel.height());
        panel.addClass("panel-refreshing");

        if(action && action === "shown" && typeof callback === "function")
            callback();
    }else{
        panel.find(".panel-refresh-layer").remove();
        panel.removeClass("panel-refreshing");

        if(action && action === "hidden" && typeof callback === "function")
            callback();
    }
}

function panel_remove(panel,action,callback){
    if(action && action === "before" && typeof callback === "function")
        callback();

    panel.animate({'opacity':0},200,function(){
        panel.parent(".panel-fullscreen-wrap").remove();
        $(this).remove();
        if(action && action === "after" && typeof callback === "function")
            callback();
    });
}
/* EOF PANEL FUNCTIONS */

/* X-NAVIGATION CONTROL FUNCTIONS */
function x_navigation_onresize(){
    return;
    var inner_port = window.innerWidth || $(document).width();

    if(inner_port < 1025){
        $("#admin_sidebar .x-navigation").removeClass("x-navigation-minimized");
        $("#page-container").removeClass("page-container-wide");
        $("#admin_sidebar .x-navigation li.active").removeClass("active");


        $("#admin_header").each(function(){
            if(!$(this).hasClass("x-navigation-panel")){
                $("#admin_header").addClass("x-navigation-h-holder").removeClass("x-navigation-horizontal");
            }
        });


    }else{
        if($("#page-container.page-navigation-toggled").length > 0){
            x_navigation_minimize("close");
        }

        $("#admin_header.x-navigation-h-holder").addClass("x-navigation-horizontal").removeClass("x-navigation-h-holder");
    }

}

function x_navigation_minimize(action){

    if(action == 'open'){
        $("#page-container").removeClass("page-container-wide");
        $("#admin_sidebar .x-navigation").removeClass("x-navigation-minimized");
        $("#admin_header .x-navigation-minimize").find(".fa").removeClass("fa-indent").addClass("fa-dedent");
    }

    if(action == 'close'){
        $("#page-container").addClass("page-container-wide");
        $("#admin_sidebar .x-navigation").addClass("x-navigation-minimized");
        $("#admin_header .x-navigation-minimize").find(".fa").removeClass("fa-dedent").addClass("fa-indent");
    }

    $("#admin_sidebar .x-navigation li.active").removeClass("active");

}

function x_navigation(){

    $("#admin_sidebar .x-navigation-control").click(function(){
        $(this).parents(".x-navigation").toggleClass("x-navigation-open");
        return false;
    });

    $("#toogle_sidebar").click(function(){

        if($("#admin_sidebar > .x-navigation").hasClass("x-navigation-minimized")){
            $("#page-container").removeClass("page-navigation-toggled");
            x_navigation_minimize("open");
        }else{
            $("#page-container").addClass("page-navigation-toggled");
            x_navigation_minimize("close");
        }
        return false;
    });

    /*$("#admin_sidebar li > a, #admin_header li > a").click(function(){
        var li = $(this).parent('li');
        var ul = li.parent("ul");
        ul.find(" > li").not(li).removeClass("active");
    });*/

    $("#admin_sidebar li").click(function(event){ //menus
        event.stopPropagation();
        var li = $(this);
        if($('.x-navigation.x-navigation-minimized').size()) li.siblings('.active').removeClass("active").find('.active').removeClass("active");
        if(li.children("ul").length > 0 || li.children(".panel").length > 0 || $(this).hasClass("xn-profile") > 0){
            if(li.hasClass("active")){
                li.removeClass("active");
                li.find("li.active").removeClass("active");
            }else
                li.addClass("active");

            if($(this).hasClass("xn-profile") > 0)
                return true;
            else
                return false;
        }
    });
}
/* EOF X-NAVIGATION CONTROL FUNCTIONS */


/* PLAY SOUND FUNCTION */
function playAudio(file){
    if(file === 'alert')
        document.getElementById('audio-alert').play();

    if(file === 'fail')
        document.getElementById('audio-fail').play();
}
/* END PLAY SOUND FUNCTION */

/* NEW OBJECT(GET SIZE OF ARRAY) */
Object.size = function(obj) {
    var size = 0, key;
    for (key in obj) {
        if (obj.hasOwnProperty(key)) size++;
    }
    return size;
};
/* EOF NEW OBJECT(GET SIZE OF ARRAY) */