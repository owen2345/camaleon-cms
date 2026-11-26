// build custom field groups with values recovered from DB received in field_values
// group_numbers (optional): the group number of each instance of a repeatable group, in the order of
// field_values. The editor keeps these numbers, so a save does not move a value to another group
// number. Only a drag changes the number of an instance, unless cama_custom_group_numbers gives
// the positions of the instances in place of the numbers.
function build_custom_field_group(field_values, group_id, fields_data, is_repeat, field_name_group, group_numbers){
    if(field_values.length == 0) field_values = [{}];
    group_numbers = cama_custom_group_numbers(group_numbers, field_values.length);
    var group_panel = $('#custom_field_group_'+group_id);
    var group_panel_body = group_panel.find(' > .panel-body');
    var group_clone = group_panel_body.children('.custom_sortable_grouped').clone().removeClass('hidden');
    var field_group_counter = 0;
    group_panel_body.children('.custom_sortable_grouped').remove();

    function instance_numbers(){
        return group_panel_body.children('.custom_sortable_grouped').map(function(){
            return parseInt($(this).find('input.cama_custom_group_number').first().val(), 10);
        }).get();
    }

    // A new instance gets the highest group number of the group plus 1.
    function next_group_number(){
        var max = -1;
        $.each(instance_numbers(), function(i, number){ if(number > max) max = number; });
        return max + 1;
    }

    function add_group(values, group_number){
        var clone = group_clone.clone();
        clone.find('input, textarea, select').not('.code_style').each(function(){ $(this).attr('name', $(this).attr('name').replace(field_name_group, field_name_group+'['+field_group_counter+']')) });
        if(is_repeat) clone.find('input.cama_custom_group_number').val(group_number === undefined ? next_group_number() : group_number);
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
            start: function (e, ui) { cama_remove_text_editors($(ui.item)); },
            stop: function (e, ui) { cama_restore_text_editors($(ui.item)); }});
        group_panel.find('.btn.duplicate_cutom_group').click(function(){ return add_group({}); });
        group_panel_body.on('click', '.header-field-grouped .del', function(){ if(confirm(I18n("msg.delete_item"))) $(this).closest('.custom_sortable_grouped').fadeOut('slow', function(){ $(this).remove(); group_panel.trigger('update_custom_group_number'); }); return false; });
        group_panel_body.on('click', '.header-field-grouped .toggleable', function(){
            if($(this).hasClass('fa-angle-down')) $(this).removeClass('fa-angle-down').addClass('fa-angle-up').closest('.header-field-grouped').next().slideUp();
            else $(this).removeClass('fa-angle-up').addClass('fa-angle-down').closest('.header-field-grouped').next().slideDown();
            return false;
        });
        // Gives the group numbers of the group, in ascending order, to the instances in their order on
        // the page. After a drag, the numbers follow the new order. After an add or a delete, the
        // instances are already in the order of their numbers, so no number changes.
        group_panel.bind('update_custom_group_number', function(){
            var numbers = instance_numbers().sort(function(a, b){ return a - b; });
            group_panel_body.children('.custom_sortable_grouped').each(function(index){ $(this).find('input.cama_custom_group_number').val(numbers[index]); });
        });
        $.each(field_values, function(index, values){ add_group(values, group_numbers[index]); });
    }else{
        add_group(field_values[0]);
    }
}

// The group numbers of the instances of a group. The save refuses a group number below 0, so the
// function gives the positions of the instances (0, 1, 2, ...) when group_numbers does not hold one
// ascending Integer from 0 to 2147483647 for each instance.
function cama_custom_group_numbers(group_numbers, count){
    var valid = $.isArray(group_numbers) && group_numbers.length == count;
    for(var i = 0; valid && i < count; i++){
        var number = group_numbers[i];
        valid = typeof number == 'number' && number % 1 === 0 && number >= 0 && number <= 2147483647 &&
            (i == 0 || number > group_numbers[i - 1]);
    }
    if(valid) return group_numbers;
    var positions = [];
    for(var position = 0; position < count; position++) positions.push(position);
    return positions;
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
        if(field_data.is_disabled){
            field.find('input, textarea, select').prop('readonly', true).filter('select').click(function(){ return false; }).focus(function(){ $(this).blur(); });
            field.find('.btn').addClass('disabled').unbind().click(function(){ return false; });
        }

        if (field_data.kind == 'checkbox'){
            field.find('input')[0].checked = value;
        }else if(value){
            field.find('.input-value').val(value).trigger('change', {field_rendered: true}).data('value', value);
        }
        $sortable.append(field);
        // A render callback failure must degrade its own field, not the page: a throw here
        // escapes the jQuery-ready handler and aborts every custom field and initialiser
        // registered after it.
        if(callback){
            if (typeof window[callback] === 'function') {
                try { window[callback](field, value); } catch(e){ console.warn('custom field render callback ' + callback + ' failed', e); }
            } else {
                console.warn('custom field render callback ' + callback + ' is not defined');
            }
        }
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
        panel.delegate('.actions .fa-times', "click", function () { if(confirm(I18n("msg.delete_item"))) $(this).closest('.editor-custom-fields').remove(); return false; });
        $sortable.sortable({ handle: ".fa-arrows", items: ' > .editor-custom-fields',
            start: function (e, ui) { cama_remove_text_editors($(ui.item)); },
            stop: function (e, ui) { cama_restore_text_editors($(ui.item)); }
        });
    }
}

// A text editor does not survive a move of its panel in the page. For this reason, a sortable removes
// the text editors of the dragged item, and sets them up again at the drop. The two functions find
// each field from its text editor, not from the element after a panel. A plugin can put its own
// element between the panel of a text editor and the field. An inline text editor has no panel in
// the item, and it stays.
// Each field keeps the settings of its text editor. mceAddEditor uses the settings of the last
// tinymce.init of the page, which can be the init of another editor.
function cama_remove_text_editors(item){
    // a copy of the list: the removal of a text editor changes the list
    $.each(tinymce.editors.slice(), function(index, editor){
        var field = editor.getElement();
        if(editor.inline || !$.contains(item[0], field)) return;
        var settings = editor.settings;
        tinymce.execCommand('mceRemoveEditor', false, editor.id);
        $(field).addClass('cama_restore_editor').data('cama_editor_settings', settings);
    });
}

function cama_restore_text_editors(item){
    item.find('.cama_restore_editor').removeClass('cama_restore_editor').each(function(){
        var settings = $(this).data('cama_editor_settings');
        $(this).removeData('cama_editor_settings');
        if(!tinymce.get(this.id)) new tinymce.Editor(this.id, settings, tinymce.EditorManager).render();
    });
}

function custom_field_colorpicker($field) {
    if ($field) {
        // Same hardening as the _val variant: prime the data cache from whatever the markup
        // carries, so a coercible or missing data-color cannot crash the widget's constructor.
        custom_field_colorpicker_val($field, $field.find(".my-colorpicker").attr('data-color'));
    }
}
function custom_field_colorpicker_val($field, value) {
    if ($field) {
        // The widget reads its colour through jQuery's data(), which coerces numeric-looking
        // attribute values to Numbers the colour parser cannot take; priming the data cache with
        // the string form is what prevents that (a throw here aborts every later jQuery-ready
        // handler, not just this group's fields). The attribute write only keeps the DOM
        // inspectable - it is never read back once the cache is set. A field with no stored
        // value keeps the markup's declared default (data-color="#fff"). This must receive the
        // per-instance clone: priming the shared template would leak the first value's colour
        // into every later instance.
        var $cp = $field.find(".my-colorpicker");
        var color = value == null || value === '' ? String($cp.attr('data-color') || '') : String(value);
        $cp.attr('data-color', color).data('color', color).colorpicker();
        // A re-render with a new value must repaint: the bare colorpicker() call is a no-op on
        // an element whose widget already exists.
        $cp.colorpicker('update');
    }
}
function custom_field_checkbox_val($field, values) {
    if(values == "t") values = 1; // fix for values saved as true
    if ($field) {
        // match by property, not a concatenated selector: option values are admin-entered free
        // text, and a quote in one made the selector throw
        $field.find('input').filter(function(){ return this.value == values; }).prop('checked', true);
    }
}
function custom_field_checkboxs_val($field, values) {
    if ($field) {
        var vals = ($.isArray(values) ? values : [values]).map(String);
        $field.find('input').filter(function(){ return vals.indexOf(this.value) != -1; }).prop('checked', true);
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
        // TinyMCE finds the field by its id, so the field gets a random id that no other element has.
        var id;
        do { id = "t_" + Math.floor((Math.random() * 100000) + 1) + "_area"; } while (document.getElementById(id));
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
        $field.find('input').filter(function(){ return this.value == value; }).prop('checked', true);
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
// The URL goes into attribute values, never into the HTML of the preview. In the HTML of the
// preview, a value with a quote and a tag adds that tag to the form.
function cama_custom_field_image_changed(field){
    var url = field.val();
    var $group = field.closest('.input-group');
    $group.find('.custom_field_image_preview').remove();
    if(url && $group.length){
        var $image = $('<img style="width: 50px; height: 20px;">').attr('src', url);
        var $link = $('<a target="_blank"></a>').attr('href', url).append($image);
        $group.append($('<span class="input-group-addon custom_field_image_preview"></span>').append($link));
    }
}

function cama_custom_field_image_remove(field){
    field.val('');
    cama_custom_field_image_changed(field);
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