// build custom field groups with values recovered from DB received in field_values
function build_custom_field_group(field_values, group_id, fields_data, is_repeat, field_name_group){
    if(field_values.length == 0) field_values = [{}];
    var group_panel = $('#custom_field_group_'+group_id);
    var group_panel_body = group_panel.find(' > .panel-body');
    var group_clone = group_panel_body.children('.custom_sortable_grouped').clone().removeClass('hidden');
    var field_group_counter = 0;
    group_panel_body.children('.custom_sortable_grouped').remove();

    function add_group(values){
        var clone = group_clone.clone();
        clone.find('input, textarea, select').not('.code_style').each(function(){ $(this).attr('name', $(this).attr('name').replace(field_name_group, field_name_group+'['+field_group_counter+']')) });
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
        new Sortable(group_panel_body[0], { handle: ".move.fa-arrows", draggable: "> .custom_sortable_grouped", animation: 150,
            onEnd: function(evt) {
                // fix tinymce: restore editors after drop
                $(evt.item).find('.cama_restore_editor').each(function () {
                    tinymce.execCommand('mceAddEditor', true, $(this).attr('id'));
                });
                group_panel.trigger('update_custom_group_number');
            },
            onStart: function(evt) { // fix tinymce
                $(evt.item).find('.mce-panel').each(function () {
                    tinymce.execCommand('mceRemoveEditor', false, $(this).next().addClass('cama_restore_editor').attr('id'));
                });
            }});
        group_panel.find('.btn.duplicate_cutom_group').click(add_group);
        group_panel_body.on('click', '.header-field-grouped .del', function(){ if(confirm(I18n("msg.delete_item"))) $(this).closest('.custom_sortable_grouped').fadeOut('slow', function(){ $(this).remove(); group_panel.trigger('update_custom_group_number'); }); return false; });
        group_panel_body.on('click', '.header-field-grouped .toggleable', function(){
            if($(this).hasClass('fa-angle-down')) $(this).removeClass('fa-angle-down').addClass('fa-angle-up').closest('.header-field-grouped').next().slideUp();
            else $(this).removeClass('fa-angle-up').addClass('fa-angle-down').closest('.header-field-grouped').next().slideDown();
            return false;
        });
        group_panel.on('update_custom_group_number', function(){ $(this).find('.custom_sortable_grouped').each(function(index){ $(this).find('input.cama_custom_group_number').val(index); }); });
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
        if(!$field.find('.group-input-fields-content').hasClass('cama_skip_cf_rename_multiple')) {
            field.find('input, textarea, select').each(function(){ $(this).attr('name', $(this).attr('name').replace('[]', '['+field_counter+']')) });
        }
        if(field_data.disabled){
            field.find('input, textarea, select').prop('readonly', true).filter('select').click(function(){ return false; }).focus(function(){ $(this).blur(); });
            field.find('.btn').addClass('disabled').off().click(function(){ return false; });
        }

        if (field_data.kind == 'checkbox'){
            field.find('input')[0].checked = value;
        }else if(value){
            field.find('.input-value').val(value).trigger('change', {field_rendered: true}).data('value', value);
        }
        $sortable.append(field);
        if(callback) window[callback](field, value);
        field_counter ++;
    }
    if(field_data.kind != 'checkbox' && values.length <= 0) {
        values = [field_data.default_value];
    }
    if(field_data.kind != 'checkboxes') {
        if (!field_data.multiple && values.length > 1) values = [values[0]];
        if (field_data.kind == 'checkbox') {
            add_field(values[0]);
        } else {
            $.each(values, function (i, value) {
                add_field(value);
            });
        }
    } else add_field(values);

    if(field_data.multiple){ // sortable actions
        panel.find('.field_multiple_btn .btn').click(function () { add_field(field_data.default_value); return false; });
        panel.on('click', '.actions .fa-times', function () { if(confirm(I18n("msg.delete_item"))) $(this).closest('.editor-custom-fields').remove(); return false; });
        new Sortable($sortable[0], { handle: ".fa-arrows", draggable: "> .editor-custom-fields", animation: 150,
            onStart: function(evt) { // fix tinymce
                $(evt.item).find('.mce-panel').each(function () {
                    tinymce.execCommand('mceRemoveEditor', false, $(this).next().addClass('cama_restore_editor').attr('id'));
                });
            },
            onEnd: function(evt) { // fix tinymce
                $(evt.item).find('.cama_restore_editor').each(function () {
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
        $field.find(".my-colorpicker").attr('data-color', value || '').colorpicker();
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
        var data = typeof(value) == 'object' ? value : JSON.parse(value);
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
function custom_field_url_callback($field) {
    if ($field) {
        if ($field.find('input').hasClass('is_translate')) {
            $field.find('input').addClass('translatable').Translatable(ADMIN_TRANSLATIONS);
        }
    }
}
function custom_field_select_callback($field, val) {
    if ($field) {
        var sel = $field.find('select.input-value');
        if (!val) sel.data('value', sel.val()); // fix for select translator
        if(sel.hasClass('is_translate')) sel.addClass('translatable').Translatable(ADMIN_TRANSLATIONS);
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
            $input.val(file.url).trigger('change');
        }
    });
}

// permit to show preview image of image custom fields
function cama_custom_field_image_changed(field){
    if(field.val()) field.closest('.input-group').append('<span class="input-group-addon custom_field_image_preview"><a href="'+field.val()+'" target="_blank"><img src="'+field.val()+'" style="width: 50px; height: 20px;"></a></span>')
    else field.closest('.input-group').find('.custom_field_image_preview').remove();
}

function cama_custom_field_image_remove(field){
    field.val('')
    field.closest('.input-group').find('.custom_field_image_preview').remove();
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

// Dynamically adjust icon contrast on colored panel headers
function cama_fix_panel_icon_contrast() {
    $('.panel-heading .panel-controls').each(function() {
        var heading = $(this).closest('.panel-heading')[0];
        if (!heading) return;
        var bg = heading.style.backgroundColor || getComputedStyle(heading).backgroundColor;
        var match = bg && bg.match(/\d+/g);
        if (match && match.length >= 3) {
            var luma = 0.299 * parseInt(match[0]) + 0.587 * parseInt(match[1]) + 0.114 * parseInt(match[2]);
            var links = $(this).find('a');
            if (luma > 150) {
                links.addClass('panel-controls-light');
            } else {
                links.removeClass('panel-controls-light');
            }
        }
    });
}

$(document).ready(function() { cama_fix_panel_icon_contrast(); });