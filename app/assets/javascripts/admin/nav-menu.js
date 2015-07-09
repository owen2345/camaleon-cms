//function do_add_item_menu(type, link, text, parent_id, extra_html)
function do_add_item_menu(data)
{
    data = $.extend({extra_html: '', parent_id: 0, id: false},data);

    var text = $.trim(data.text);
    var type = data.type;
    var link = data.link ? data.link.toString() : "";
    var parent_id = data.parent_id;
    var extra_html = data.extra_html;
    var id = data.id ? data.id : $("#nestable .dd-item").length + 1;

    var link_data = '';

    $("#menu_form .alert.alert-info").html(lang.message_edit_menu);
    if (type == "post" || type == "category"){
        link_data = '<a class="text-edit" title="'+lang.edit+'" target="_blank" href="'+data.url_edit+'" rel="1"><i class="fa fa-edit"></i></a>'
    }else if(type == "external"){
        link_data = '<a class="text-edit" title="'+lang.edit+'" href="'+data.url_content+'" onclick="do_edit_menu(this); return false;" rel="1"><i class="fa fa-edit"></i></a>'
    }else{

    }
    var item = '<li class="dd-item dd3-item" data-label="'+text.replace(/"/g, '\"')+'" data-type="'+type+'" data-link="'+link.replace('"', '\"')+'" data-id="'+id+'" data-parent="'+(parent_id ? parent_id : "")+'"><div class="dd-handle dd3-handle"></div> <div class="dd3-content"><span>'+text + "</span> " + extra_html +' <span class="label">'+type+'</span> '+ link_data +' <a href="#" onclick="do_delete_menu(this); return false;" class="text-danger" title="'+lang.delete+'"><i class="fa fa-times-circle"></i></a> </div></li>';
    if(parent_id > 0)
    {
        var parent = $("#nestable").find("*[data-id='"+parent_id+"']");
        if(!parent.children(".dd-list").size())
            parent.append("<ol class='dd-list'></ol>");
        parent.children(".dd-list").append(item);
    }else
        $("#nestable").children(".dd-list").append(item);

    $('a.text-danger, a.text-edit').tooltip();
    return id;
}



function manage_add_links_to_menu(){
    form.find(".add_links_to_menu").click(function(){
        var $parent = $(this).parents(".panel");
        $parent.find(":checkbox").filter(":checked").each(function()
        {
            var data = $(this).parents(".class_type").data();
            var data_l = $(this).parents(".class_slug").data();

            $(this).removeAttr("checked");
            // do_add_item_menu(data.type, $(this).val(), $(this).parent().text());
            do_add_item_menu({type: data.type, link: $(this).val(), url_edit: data_l.post_link_edit, text: $(this).parent().text()});
        });

        return false;
    });
}



function manage_external_links()
{
    form.find("#add_external_link").click(function()
    {
        if(form.find("#external_label").val())
        {
            do_add_item_menu({type: 'external', link: form.find("#external_url").val(), text: form.find("#external_label").val(), url_content: RENDER_FORM});
            form.find("#menu_external_link input").val("");
            form.find("#external_label").closest(".form-group").removeClass("error");
        }
        else
            form.find("#external_label").closest(".form-group").addClass("error");

        return false;
    });
    $(".accordion .panel-title a").click(function(){
        onresize();
    })
}

function do_delete_menu(link)
{
    var msg = $(link).closest("li.dd-item").children("ol").size()? lang.message_remove_items_submenu : lang.message_delete_item;

    if (confirm(msg)) {
        $(link).closest("li.dd-item").remove();
    } else {
        false;
    }

}

function do_edit_menu(link)
{
    var li = $(link).closest("li");
    open_modal({title: "Edit Menu", url: $(link).attr("href"), mode: "ajax", callback: function(modal){
        modal.find(".panel-footer").html("<button type='submit' class='btn btn-primary'>Update</button>");
        var form = modal.find("form");
        console.log(form, li);
        form.find("#external_label").val(li.attr("data-label"));
        form.find("#external_url").val(li.attr("data-link"));
        init_form_validations(form);
        form.submit(function(){

            li.attr("data-label", form.find("#external_label").val());
            li.attr("data-link", form.find("#external_url").val());
            li.children(".dd3-content").children("span:first").html(form.find("#external_label").val());
            modal.modal("hide");
            return false;
        });
    }});
    return;
}