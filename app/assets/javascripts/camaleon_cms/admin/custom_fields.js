function build_custom_field(values, multiple, field_key, rand, default_value){
    var $content = $("#content-field-"+rand);
    var $sortable = $("#sortable-"+rand);
    var callback = $content.find('.clone-field .group-input-fields-content').attr('data-callback-function');
    var callback_set_value = $content.find('.clone-field .group-input-fields-content').attr('data-callback-set-value');
    var $field = $('<li>' + $content.find('.clone-field').html() + '</li>');

    function add_field(value){
        var field = $field.clone(true);
        if(value) field.find('.input-value').val(value);
        $sortable.append(field);
        if(value && callback_set_value)eval(callback_set_value+"(field, value);")
        else if(callback) eval(callback+"(field);")
    }

    if(values.length > 0) {
        if(field_key == 'checkboxes'){
            add_field(values);
        }else{
            if(!multiple && values.length > 1) values = [values[0]];
            $.each(values, function(i, value){
                add_field(value);
            });
        }
    } else add_field(default_value);

    if(multiple) {
        $content.find('.btn-add-field').click(function(){
            add_field(default_value);
            return false;
        });
        $sortable.delegate('.actions .fa-times', "click", function(){
            var parent = $(this).parents('li');
            if(confirm(I18n("msg.delete_item"))){
                parent.remove();
            }
            return false;
        });
        $sortable.find('li:first .fa-times').hide();
        $sortable.sortable({
            handle: ".fa-arrows"
        });
    }

    $content.find('.clone-field').remove();
}

function custom_field_colorpicker($field){ if($field){ $field.find(".my-colorpicker").colorpicker(); } }
function custom_field_colorpicker_val($field, value){ if($field){ $field.find(".my-colorpicker").attr('data-color', value).colorpicker(); } }
function custom_field_checkbox_val($field, values){
    if($field){
        $field.find('input[value="'+values+'"]').prop('checked', true);
    }
}
function custom_field_checkboxs_val($field, values){
    if($field){
        var selector = values.map(function(value){
            return "input[value='"+value+"']"
        }).join(',');
        $field.find('input').prop('checked', false);
        $field.find(selector).prop('checked', true);
    }
}
function custom_field_date($field){
    if($field){
        var box = $field.find(".date-input-box");
        if(box.hasClass('is_datetimepicker')){
            box.datetimepicker({
                language: 'es',
                pick12HourFormat: true,
                format: 'yyyy-MM-dd hh:mm'
            });
        }else{
            box.datepicker({
                language: 'es',
                format: 'yyyy-mm-dd',
                autoclose: true,
                todayBtn: "linked"
            });
        }
    }
}
function custom_field_editor($field){
    if($field){
        var id = "t_" + Math.floor((Math.random() * 100000) + 1) + "_area";
        var textarea = $field.find('textarea').attr('id', id);
        if(textarea.hasClass('is_translate')) {
            textarea.addClass('translatable').Translatable(ADMIN_TRANSLATIONS);
            var inputs = textarea.data("translation_inputs");
            if(inputs){ // multiples languages
                for(var lang in inputs){
                    tinymce.init(cama_get_tinymce_settings({selector: '#' + inputs[lang].attr("id"), height: 120}));
                }
                return;
            }
        }
        tinymce.init(cama_get_tinymce_settings({selector: '#' + id, height: 120}));
    }
}
function custom_field_field_attrs_val($field, value){
    if($field){
        var data = $.parseJSON(value);
        $field.find('.input-attr').val(data.attr);
        $field.find('.input-value').val(data.value)
    }
}
function custom_field_radio_val($field, value){
    if($field){
        $field.find('input').prop('checked', false);
        $field.find("input[value='"+value+"']").prop('checked', true);
    }
}
function custom_field_text_area($field){
    if($field){
        if($field.find('textarea').hasClass('is_translate')) {
            $field.find('textarea').addClass('translatable').Translatable(ADMIN_TRANSLATIONS);
        }
    }
}
function custom_field_text_box($field){
    if($field){
        if($field.find('input').hasClass('is_translate')) {
            $field.find('input').addClass('translatable').Translatable(ADMIN_TRANSLATIONS);
        }
    }
}

function load_upload_audio_field(dom){
    var $input = $(dom).parents('li:first').find('input');
    $.fn.upload_elfinder({
        type: "audio",
        selected: function(res){
            var file = _.first(res);
            $input.val(file.url.to_url());
        }
    });
}
function load_upload_file_field(dom){
    var $input = $(dom).parents('li:first').find('input');
    $.fn.upload_elfinder({
        type: $input.data("formats") ? $input.data("formats") : "all",
        selected: function(res){
            var file = _.first(res);
            $input.val(file.url.to_url());
        }
    });
}
function load_upload_image_field(dom){
    var $input = $(dom).parents('li:first').find('input');
    $.fn.upload_elfinder({
        type: "image",
        selected: function(res){
            var file = _.first(res);
            $input.val(file.url.to_url());
        }
    });
}
function load_upload_video_field(dom){
    var $input = $(dom).parents('li:first').find('input');
    $.fn.upload_elfinder({
        type: "video",
        selected: function(res){
            var file = _.first(res);
            $input.val(file.url.to_url());
        }
    });
}
