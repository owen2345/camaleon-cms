// build custom field groups with values recovered from DB received in field_values
function build_custom_field_group(field_values, group_id, fields_data, is_repeat){
    if(field_values.length == 0) field_values = [{}];
    var group_panel = $('#custom_field_group_'+group_id);
    var group_panel_body = group_panel.find(' > .panel-body');
    var group_clone = group_panel_body.children('.custom_sortable_grouped').clone().removeClass('hidden');
    var field_group_counter = 0;
    group_panel_body.children('.custom_sortable_grouped').remove();

    function add_group(values){
        var clone = group_clone.clone();
        clone.find('input, textarea, select').not('.code_style').each(function(){ $(this).attr('name', $(this).attr('name').replace('field_options', 'field_options['+field_group_counter+']')) });
        group_panel_body.append(clone);
        group_panel.trigger('update_custom_group_number');
        for(var k in fields_data){
            cama_build_custom_field(clone.find('.content-field-'+fields_data[k].id), fields_data[k], values[k]);
        }
        if(field_group_counter == 0) clone.children('.header-field-grouped').find('.del').remove();
        field_group_counter ++;
        return false;
    }

    if(is_repeat){
        group_panel_body.sortable({ handle: ".move.fa-arrows", items: ' > .custom_sortable_grouped',
            update: function(){ group_panel.trigger('update_custom_group_number'); },
            start: function (e, ui) { // fix tinymce
                $(ui.item).find('.mce-panel').each(function () {
                    tinymce.execCommand('mceRemoveEditor', false, $(this).next().addClass('cama_restore_editor').attr('id'));
                });
            },
            stop: function (e, ui) { // fix tinymce
                $(ui.item).find('.cama_restore_editor').each(function () {
                    tinymce.execCommand('mceAddEditor', true, $(this).attr('id'));
                });
            }});
        group_panel.find('.btn.duplicate_cutom_group').click(add_group);
        group_panel_body.on('click', '.header-field-grouped .del', function(){ if(confirm(I18n("msg.delete_item"))) $(this).closest('.custom_sortable_grouped').fadeOut('slow', function(){ $(this).remove(); group_panel.trigger('update_custom_group_number'); }); return false; });
        group_panel_body.on('click', '.header-field-grouped .toggleable', function(){
            if($(this).hasClass('fa-angle-down')) $(this).removeClass('fa-angle-down').addClass('fa-angle-up').closest('.header-field-grouped').next().slideUp();
            else $(this).removeClass('fa-angle-up').addClass('fa-angle-down').closest('.header-field-grouped').next().slideDown();
            return false;
        });
        group_panel.bind('update_custom_group_number', function(){ $(this).find('.custom_sortable_grouped').each(function(index){ $(this).find('input.cama_custom_group_number').val(index); }); });
        $.each(field_values, function(field_val, key){ add_group(this); });
    }else{
        add_group(field_values[0]);
    }
}

function cama_build_custom_field(panel, field_data, values){
    values = values || [];
    var field_counter = 0;
    var $field = panel.clone().wrap('li');
    panel.html("<div class='cama_w_custom_fields'></div>"+(field_data.multiple ? "<div class='field_multiple_btn'> <a href='#' class='btn btn-warning btn-xs'> <i class='fa fa-plus'></i> "+panel.attr('data-add_field_title')+"</a></div>" : ''));
    var field_actions = '<div class="actions"><i style="cursor: move" class="fa fa-arrows"></i> <i style="cursor: pointer" class="fa fa-times text-danger"></i></div>';
    var callback = $field.find('.group-input-fields-content').attr('data-callback-render');
    var $sortable = panel.children('.cama_w_custom_fields');
    function add_field(value){
        var field = $field.clone(true);
        if(field_data.multiple) {
            field.prepend(field_actions);
            if(field_counter == 0) field.children('.actions').find('.fa-times').remove();
        }
        field.find('input, textarea, select').each(function(){ $(this).attr('name', $(this).attr('name').replace('[]', '['+field_counter+']')) });
        if(field_data.disabled){
            field.find('input, textarea, select').prop('readonly', true).filter('select').click(function(){ return false; }).focus(function(){ $(this).blur(); });
            field.find('.btn').addClass('disabled').unbind().click(function(){ return false; });
        }

        if(value) field.find('.input-value').val(value);
        $sortable.append(field);
        if(callback) eval(callback + "(field, value);");
        field_counter ++;
    }
    if(values.length <= 0) values = [field_data.default_value];
    if(field_data.kind != 'checkboxes') {
        if (!field_data.multiple && values.length > 1) values = [values[0]];
        $.each(values, function (i, value) {
            add_field(value);
        });
    } else add_field(values);

    if(field_data.multiple){ // sortable actions
        panel.find('.field_multiple_btn .btn').click(function () { add_field(field_data.default_value); return false; });
        panel.delegate('.actions .fa-times', "click", function () { if(confirm(I18n("msg.delete_item"))) $(this).closest('.editor-custom-fields').remove(); return false; });
        $sortable.sortable({ handle: ".fa-arrows", items: ' > .editor-custom-fields',
            start: function (e, ui) { // fix tinymce
                $(ui.item).find('.mce-panel').each(function () {
                    tinymce.execCommand('mceRemoveEditor', false, $(this).next().addClass('cama_restore_editor').attr('id'));
                });
            },
            stop: function (e, ui) { // fix tinymce
                $(ui.item).find('.cama_restore_editor').each(function () {
                    tinymce.execCommand('mceAddEditor', true, $(this).attr('id'));
                });
            }
        });
    }
}

function custom_field_colorpicker($field) {
    if ($field) {
        $field.find(".my-colorpicker").colorpicker();
    }
}
function custom_field_colorpicker_val($field, value) {
    if ($field) {
        $field.find(".my-colorpicker").attr('data-color', value).colorpicker();
    }
}
function custom_field_checkbox_val($field, values) {
    if(values == "t") values = 1; // fix for values saved as true
    if ($field) {
        $field.find('input[value="' + values + '"]').prop('checked', true);
    }
}
function custom_field_checkboxs_val($field, values) {
    if ($field) {
        var selector = values.map(function (value) {
            return "input[value='" + value + "']"
        }).join(',');
        $field.find('input').prop('checked', false);
        $field.find(selector).prop('checked', true);
    }
}
function custom_field_date($field) {
    if ($field) {
        var box = $field.find(".date-input-box");
        if (box.hasClass('is_datetimepicker')) {
            box.datetimepicker({ format: 'YYYY-MM-DD HH:mm' });
        } else {
            box.datepicker();
        }
    }
}
function custom_field_editor($field) {
    if ($field) {
        var id = "t_" + Math.floor((Math.random() * 100000) + 1) + "_area";
        var textarea = $field.find('textarea').attr('id', id);
        if (textarea.hasClass('is_translate')) {
            textarea.addClass('translatable').Translatable(ADMIN_TRANSLATIONS);
            var inputs = textarea.data("translation_inputs");
            if (inputs) { // multiples languages
                for (var lang in inputs) {
                    tinymce.init(cama_get_tinymce_settings({
                        selector: '#' + inputs[lang].attr("id"),
                        height: 120
                    }));
                }
                return;
            }
        }
        tinymce.init(cama_get_tinymce_settings({
            selector: '#' + id,
            height: 120
        }));
    }
}
function custom_field_field_attrs_val($field, value) {
    if ($field) {
        value = value || '{}'
        var data = typeof(value) == 'object' ? value : $.parseJSON(value);
        $field.find('.input-attr').val(data.attr);
        $field.find('.input-value').val(data.value)
        $field.find('.input-attr, .input-value').filter('.is_translate').addClass('translatable').Translatable(ADMIN_TRANSLATIONS);
    }
}
function custom_field_radio_val($field, value) {
    if ($field) {
        $field.find('input').prop('checked', false);
        $field.find("input[value='" + value + "']").prop('checked', true);
    }
}
function custom_field_text_area($field) {
    if ($field) {
        if ($field.find('textarea').hasClass('is_translate')) {
            $field.find('textarea').addClass('translatable').Translatable(ADMIN_TRANSLATIONS);
        }
    }
}
function custom_field_text_box($field) {
    if ($field) {
        if ($field.find('input').hasClass('is_translate')) {
            $field.find('input').addClass('translatable').Translatable(ADMIN_TRANSLATIONS);
        }
    }
}

function load_upload_audio_field(thiss) {
    var $input = $(thiss).prev();
    $.fn.upload_filemanager({
        formats: "audio",
        selected: function (file, response) {
            $input.val(file.url);
        }
    });
}
function load_upload_file_field(thiss) {
    var $input = $(thiss).prev();
    $.fn.upload_filemanager({
        formats: $input.data("formats") ? $input.data("formats") : "",
        selected: function (file, response) {
            $input.val(file.url);
        }
    });
}
function load_upload_private_file_field(thiss) {
    var $input = $(thiss).prev();
    $.fn.upload_filemanager({
        formats: $input.data("formats") ? $input.data("formats") : "",
        selected: function (file, response) {
            $input.val(file.url.split('?file=')[1].replace(/%2/g, '/'));
        },
        private: true
    });
}
function load_upload_image_field($input) {
    $.fn.upload_filemanager({
        formats: "image",
        dimension: $input.attr("data-dimension") || '',
        versions: $input.attr("data-versions") || '',
        thumb_size: $input.attr("data-thumb_size") || '',
        selected: function (file, response) {
            $input.val(file.url);
        }
    });
}
function load_upload_video_field(thiss) {
    var $input = $(thiss).prev();
    $.fn.upload_filemanager({
        formats: "video",
        selected: function (file, response) {
            $input.val(file.url);
        }
    });
}
