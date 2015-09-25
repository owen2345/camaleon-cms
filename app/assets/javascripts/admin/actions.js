jQuery(function($){
    // initialize all validations for forms
    init_form_validations();
    setTimeout(page_actions, 1000);
});

// basic and common actions
var page_actions = function(){
    // button actions
    $('#admin_content table').addClass('table').wrap('<div class="table-responsive"></div>');
    $('#admin_content a[role="back"]').on('click',function(){ window.history.back(); return false; });
    $('[data-toggle="tooltip"], a[title!=""]', "#admin_content").not(".skip_tooltip").tooltip();

    /* PANELS */
    $("#admin_content").on("click", ".panel .panel-collapse", function(){
        panel_collapse($(this).parents(".panel:first"));
        $(this).parents(".dropdown").removeClass("open");
        return false;
    });
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