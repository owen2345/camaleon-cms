//function do_add_item_menu(type, link, text, parent_id, extra_html)
function do_add_item_menu(data){
    data = $.extend({extra_html: '', parent_id: 0, id: false},data);
    var text = $.trim(data.text);
    var type = data.type;
    var link = data.link ? data.link.toString() : "";
    var parent_id = data.parent_id;
    var extra_html = data.extra_html;
    var item_id = data.item_id;
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

    var item = $('<li class="dd-item dd3-item" data-type="'+type+'" data-id="'+id+'" data-item_id="'+item_id+'" data-parent="'+(parent_id ? parent_id : "")+'"><div class="dd-handle dd3-handle"></div> <div class="dd3-content"><span>'+text + "</span> " + extra_html +' <span class="label">'+type+'</span> '+ link_data +' <a href="#" onclick="do_delete_menu(this); return false;" class="text-danger" title="'+I18n("button.delete")+'"><i class="fa fa-times-circle"></i></a> </div></li>');
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
        setTimeout(function(){
            f.find("input:last").focus();
            f.find(".has-error").removeClass("has-error").end().find("label.error").remove();
        }, 100);
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
    open_modal({title: "Edit Menu", url: RENDER_FORM.replace('-9999', li.attr('data-item_id')), mode: "ajax", callback: function(modal){
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
    open_modal({id: 'menu_item_'+li.attr('data-id'), title: "Configuration Menu", url: RENDER_FORM.replace('-9999', li.attr('data-item_id'))+"&custom_fields=true", mode: "ajax", callback: function(modal){
        modal.attr('data-skip_destroy', true);
        var form = modal.find("form");
        form.submit(function(){
            if(!form.valid()) return false;
            form.find(".translate-item").trigger("change_in");
            li.attr("data-fields", JSON.stringify(form.serializeObject().field_options));
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
            item_id: item.id,
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
                main_menus_panel.flash_message(I18n("msg.updated_success"), "success");
            }
        });
        return false;
    });
}