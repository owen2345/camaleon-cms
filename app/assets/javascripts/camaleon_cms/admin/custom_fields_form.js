// add actions to assign custom fields to any model selected
jQuery(function($){
    var panel = $("#cama_custom_field_form");
    var group_class_name = panel.attr("data-group_class_name");
    var $content_fields = $( "#sortable-fields", panel);
    $content_fields.sortable({
        handle: ".panel-sortable"
    });
    var slugger_count = $content_fields.children().length;
    cama_custom_field_set_slug();

    $("#content-items-default > a", panel).click(function(){
        var href = $(this).attr('href');
        showLoading();
        $.post(href, function(html){
            hideLoading();
            var li = $('<li class="item">' + html + '</li>');
            $content_fields.append(li);
            cama_custom_field_set_slug(li);
            var title_field = li.find("input.text-title");
            title_field.val(title_field.val() + '-' + (slugger_count ++));
            title_field.trigger("keyup");
            $('[data-toggle="tooltip"], a[title!=""]', $content_fields).tooltip();
        });
        return false;
    });

    panel.on("click", ".panel-delete", function(){
        var parent = $(this).parents(".item:first");
        if(confirm(I18n("msg.delete_item"))){
            parent.remove()
        }
        return false;
    });

    $('#select_assign_group', panel).change(function(){
        var option = $(this).find('option:checked');
        if(option.attr('value') == '_post_simple'){
            $('#select_post_simple', panel).show().removeAttr('disabled');
        }else{
            $('#select_post_simple', panel).hide().attr('disabled','disabled');
        }
        var txt_help = option.data('help');
        if(txt_help) txt_help = '<div class="alert alert-info"><i class="fa fa-info-circle"></i>&nbsp; ' + txt_help + ' </div>';
        $('#select_assign_group_help', panel).html(txt_help);
        $('#select_assign_group_caption', panel).val(option.parent('optgroup').attr("label") + ' ' + option.text());
    }).val((group_class_name.search("Post,") == 0) ? '_post_simple':  group_class_name).trigger('change');

    $('#select_post_simple', panel).change(function(){
        var option = $(this).find('option:checked');
        var txt_help = option.data('help');
        if(txt_help) txt_help = '<div class="alert alert-info"><i class="fa fa-info-circle"></i>&nbsp; ' + txt_help + ' </div>';
        $('#select_assign_group_help', panel).html(txt_help);
        $('#select_assign_group_caption', panel).val(option.parent('optgroup').attr("label") + ': ' + option.text());
    }).val(group_class_name).trigger('change');

    function cama_custom_field_set_slug(_panel){
        $('.text-slug:not(.runned)', _panel || panel).each(function(){
            var $parent = $(this).parents('.panel-item');
            var $label = $parent.find('.span-title');
            $(this).slugify($parent.find('.text-title'), {
                    slugFunc: function(str, originalFunc) {
                        $label.html(str);
                        return originalFunc(str);
                    }
                }
            );
            $(this).addClass('runned')
        });
    }
});