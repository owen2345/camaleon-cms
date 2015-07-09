jQuery(function(){
    $("#content-widget .ajax_link, #content-sidebar .ajax_link").ajax_modal();
    $( "#content-widget .widgets-available" ).find(".panel-widget").draggable({
        helper: "clone",
        cancel: ".informer"

    });

    var $content_sidebar = $( "#content-sidebar .item-sidebar .sidebar-body" );
    $content_sidebar.droppable({
        activeClass: "ui-state-default",
        hoverClass: "ui-state-hover",
        accept: ":not(.ui-sortable-helper)",
        drop: function( event, ui ) {
            var widget_id = ui.draggable.data('id'); //draggedID
            var sidebar_id = $(this).attr('data-id');  //droppedID
            var href = url_assign_widget_sidebar.replace(-1,sidebar_id);
            $.get(href, {widget_id: widget_id},function(html){
                $(event.target).append(html);
                init_form_validations($(event.target).find("form:last"));
            });
            return false;
        }
    }).sortable({
        cursor: "move",
        axis: "y",
        items: "form",
        handle: ".panel-heading",
        update: function(ui){
            var pos = [];
            $(ui.target).find("form").each(function(index, form){
                form = $(form);
                if(form.find(".item_order").length == 0)
                    form.append('<input type="hidden" name="assign[item_order]" class="item_order">');
                form.find(".item_order").val(index);
                pos.push(form.data("id"));
            });
            $.post(sidebar_reorder_url.replace("-1", $(ui.target).closest(".item-sidebar").data("id")), {pos: pos});
        }
    });

    $("#content-sidebar").on("click", ".btn-delete-widget", function(){
        var link = $(this);
        if(!confirm(link.data("confirm"))) return false;
        $.ajax({method: "DELETE", url: link.data("href"), success: function(res){
            if(!res){
                link.closest("form").remove();
            }
        }});
        return false;

    });
});