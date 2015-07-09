// This is a manifest file that'll be compiled into application.js, which will include all the files
// listed below.
//
// Any JavaScript/Coffee file within this directory, lib/assets/javascripts, vendor/assets/javascripts,
// or vendor/assets/javascripts of plugins, if any, can be referenced here using a relative path.
//
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// compiled file.
//
// Read Sprockets README (https://github.com/sstephenson/sprockets#sprockets-directives) for details
// about supported directives.
//
//= require jquery
//= require bootstrap.min.js
//= require ./queryLoader
// require ./jquery.parallax-1.1.3
//= require ./jquery.localscroll-1.2.7-min
//= require ./jquery.scrollTo-1.4.2-min
//= require ./waypoints
//= require ./jquery.appear
//= require ./custom
//= require ./jquery-hover-effect
//= require ./jquery.smint
//= require ./counters
//= require ./jquery.fancybox-v=2.1.5
//= require ./jquery.fancybox-media-v=1.0.6
//= require ./nimble
//= require ./skdslider.min
//= require_self

//stickey header
if(is_home == "true"){
    jQuery(function() {

        var scroll_time;
        $(window).scroll(function() {
            var windscroll = $(window).scrollTop();
            if (windscroll >= 40) { jQuery("#main_menu").addClass("smallheader"); } else { jQuery("#main_menu").removeClass("smallheader"); }
            if(scroll_time) clearTimeout(scroll_time);
            scroll_time = setTimeout(updateScrollMenu, 200);
        }).scroll().resize(function(){ updateScrollMenuData(); });

        $('#main_menu').localScroll({offset: {left: 0, top: -70 }});

        // carousels
        jQuery('.carousel').carousel({
            interval: 2000
        });

        // gallery
        jQuery('#portfolio .da-thumbs > li').hoverdir();

        // skills
        var skills = jQuery('#expertise .skillbar');
        skills.find("a").click(function(){ $(this).find(".skillbar-title").toggleClass("open"); return false; });
        $(window).scroll(function() {
            skills.each(function(){ jQuery(this).find('.skillbar-bar').animate({width:jQuery(this).attr('data-percent') },6000); });
        });

        // banner
        jQuery('#demo1').skdslider({'delay':5000, 'animationSpeed': 2000,'showNextPrev':true,'showPlayButton':true,'autoSlide':true,'animationType':'fading'});

        // home fixes
        (function($) {
            if (screen.width <720 ){ $('div, img, input, textarea, button, a').removeClass('animate'); }// to remove transition
            setTimeout(function(){ $(window).resize(); }, 5000); //gallery fix
            setTimeout(function(){ $(window).resize(); }, 1000); //gallery fix
        })(jQuery);
    });

}else{ //inner pages

    $(window).scroll(function() {
        var windscroll = $(window).scrollTop();
        if (windscroll >= 40) { jQuery("#main_menu").addClass("smallheader"); } else { jQuery("#main_menu").removeClass("smallheader"); }
    }).scroll();
    setTimeout(function(){ $('#main_menu li a[href^="#"]').each(function(){ $(this).attr("href", ROOT_URL+$(this).attr("href")) }); }, 800);
}

$(document).ready(function($) {
    $('.fancybox').fancybox();
    $('.fancybox-media').fancybox({
        openEffect  : 'none',
        closeEffect : 'none',
        helpers : {
            media : {}
        }
    });
});(jQuery);

window.addEventListener('DOMContentLoaded', function() {
    new QueryLoader2(document.querySelector("body"), {
        barColor: "#efefef",
        backgroundColor: $("footer").css("border-top-color"),
        percentage: true,
        barHeight: 1,
        minimumTime: 200,
        fadeOutTime: 1000,
        onComplete: function(){
            $("#qLtempOverlay").hide();
        }
    });
});

//////////////////// menus
var scroll_data;
var menu_list;
function updateScrollMenu(){
    var windscroll = $(window).scrollTop() + 150;
    if(!menu_list) menu_list = $("#main_menu .navbar-nav li");
    if(!scroll_data) updateScrollMenuData();
    menu_list.removeClass('active');
    for(i in scroll_data){
        var item = scroll_data[i];
        if(item.top < windscroll && windscroll < (item.top + item.height) ){
            menu_list.find('a[href="#'+item.id+'"]').parent().addClass('active').parentsUntil("#main_menu", "li").addClass('active');
        }
    }
}

function updateScrollMenuData(){
    scroll_data = {};
    $('#warp > .section').each(function(i) {
        scroll_data[i] = {top: $(this).position().top, height: $(this).height(), id: $(this).attr("id"), section: $(this)};
    });
}
