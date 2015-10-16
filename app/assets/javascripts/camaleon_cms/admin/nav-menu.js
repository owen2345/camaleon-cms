//function do_add_item_menu(type, link, text, parent_id, extra_html)
function do_add_item_menu(data){
    data = $.extend({extra_html: '', parent_id: 0, id: false},data);
    var text = $.trim(data.text);
    var type = data.type;
    var link = data.link ? data.link.toString() : "";
    var parent_id = data.parent_id;
    var extra_html = data.extra_html;
    var id = data.id ? data.id : $("#nestable .dd-item").length + 1;

    var link_data = '';

    if (type == "post" || type == "category"){
        link_data = '<a class="text-edit" title="'+I18n("button.edit")+'" target="_blank" href="'+data.url_edit+'" rel="1"><i class="fa fa-edit"></i></a>'
    }else if(type == "external"){
        link_data = '<a class="text-edit" title="'+I18n("button.edit")+'" href="'+data.url_content+'" onclick="do_edit_menu(this); return false;" rel="1"><i class="fa fa-edit"></i></a>'
    }else{

    }
    // custom fields icon
    if(main_menus_panel.attr("data-fields_support") == "true") link_data += '<a class="text-edit" title="'+I18n("button.settings")+'" href="'+data.url_content+'" onclick="do_settings_menu(this); return false;" rel="1"><i class="fa fa-cog"></i></a>';

    var item = $('<li class="dd-item dd3-item" data-type="'+type+'" data-id="'+id+'" data-parent="'+(parent_id ? parent_id : "")+'"><div class="dd-handle dd3-handle"></div> <div class="dd3-content"><span>'+text + "</span> " + extra_html +' <span class="label">'+type+'</span> '+ link_data +' <a href="#" onclick="do_delete_menu(this); return false;" class="text-danger" title="'+I18n("button.delete")+'"><i class="fa fa-times-circle"></i></a> </div></li>');
    item.attr("data-fields", data.fields).attr("data-label", text).attr("data-link", link);
    if(parent_id > 0)
    {
        var parent = $("#nestable").find("*[data-id='"+parent_id+"']");
        if(!parent.children(".dd-list").size())
            parent.append("<ol class='dd-list'></ol>");
        parent.children(".dd-list").append(item);
    }else
        $("#nestable", main_menus_panel).children(".dd-list").append(item);

    $('a.text-danger, a.text-edit', item).tooltip();
    return id;
}

function manage_add_links_to_menu(){
    main_menus_panel.find(".add_links_to_menu").click(function(){
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

function manage_external_links(){
    main_menus_panel.find("form.form-custom-link").submit(function(){
        var f = $(this);
        if(!f.valid()) return false;
        do_add_item_menu({type: 'external', link: f.find("#external_url").val(), text: f.find("#external_label").val(), url_content: RENDER_FORM});
        f[0].reset();
        return false;
    });

    // custom menus
    main_menus_panel.find(".add_links_custom_to_menu").click(function(){
        var $parent = $(this).parents(".panel");
        $parent.find(":checkbox").filter(":checked").each(function()
        {
            var data = $(this).parents(".class_type").data();
            var data_l = $(this).parents(".class_slug").data();
            do_add_item_menu({type: 'external', link: $(this).val(), text: $(this).parent().text(), url_content: RENDER_FORM});
            $(this).removeAttr("checked");
        });
        return false;
    });
}

function do_delete_menu(link){
    var msg = $(link).closest("li.dd-item").children("ol").size()? I18n("msg.remove_items_submenu") : I18n("msg.delete_item");
    if (confirm(msg)) {
        $(link).closest("li.dd-item").remove();
    } else {
        false;
    }
}

// edit form for custom links
function do_edit_menu(link){
    var li = $(link).closest("li");
    open_modal({title: "Edit Menu", url: $(link).attr("href"), mode: "ajax", callback: function(modal){
        modal.find(".panel-footer").html("<button type='submit' class='btn btn-primary'>Update</button>");
        var form = modal.find("form");
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

// edit form for custom fields
function do_settings_menu(link){
    var li = $(link).closest("li");
    open_modal({title: "Configuration Menu", url: $(link).attr("href")+"&custom_fields=true", mode: "ajax", callback: function(modal){
        var form = modal.find("form");
        setTimeout(function(){
            form.find(".translated-item").trigger("trans_integrate");
            var data = eval("("+(li.attr("data-fields")||"{}")+")");
            for(var key in data){
                if(data[key]) form.find("[name='field_options["+key+"][values][]']").val(data[key]);
            }
            init_form_validations(form);
        }, 300);
        form.submit(function(){
            if(!form.valid()) return false;
            form.find(".translated-item").trigger("trans_integrate");
            var data = {};
            var form_fields = form.serializeObject().field_options;
            console.log(form_fields);
            for(var key in form_fields){
                data[key] = form.find("[name='field_options["+key+"][values][]']").val();
                console.log("ssss", data);
            }
            li.attr("data-fields", JSON.stringify(data));
            modal.modal("hide");
            return false;
        });
    }});
    return;
}

// render the menu with saved items
function render_menu(items){
    $.each(items, function (i, item) {
        var r_id = do_add_item_menu({
            id: item.id,
            type: item.type,
            link: item.link,
            url_edit: item.url_edit,
            text: item.label,
            parent_id: item.parent,
            url_content: RENDER_FORM,
            fields: item.fields
        });
    });
    $('#nestable', main_menus_panel).nestable({maxDepth: 20}).on('change', function (a) {
        null
    });

    manage_external_links(main_menus_panel);
    manage_add_links_to_menu();

    main_menus_panel.find(".disabled *").unbind().click(function (event) {
        return false;
    });

    $("#menu_items .tabs .nav").each(function () {
        if ($(this).children("li").size() == 1) {
            $(this).children("li").remove();
        }
    });

    // save menu items (main form)
    $("#menu_form").submit(function () {
        var menu_data = $('#nestable').nestable("serialize").length == 0 ? [] : $('#nestable').nestable("serialize");
        showLoading();
        $.post($(this).attr("action"), $.extend({menu_data: menu_data}, $(this).serializeObject()), function (res) {
            if (res.new) {
                location.href = res.redirect;
            } else {
                hideLoading();
            }
        });
        return false;
    });
}