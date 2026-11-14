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
    _change_additional_select(option);
    _show_help(option);
    $('#select_assign_group_caption', panel).val(option.parent('optgroup').attr("label") + ' ' + option.text());
  }).val(_search_group_class_name(group_class_name)).trigger('change');

  $('#select_post_simple', panel).change(function(){
    var option = $(this).find('option:checked');
    _show_help(option);
    $('#select_assign_group_caption', panel).val(option.parent('optgroup').attr("label") + ': ' + option.text());
  }).val(group_class_name).trigger('change');

  $('#select_category_simple', panel).change(function(){
    var option = $(this).find('option:checked');
    _show_help(option);
    $('#select_assign_group_caption', panel).val(option.parent('optgroup').attr("label") + ': ' + option.text());
  }).val(group_class_name).trigger('change');

  // The help of an option is text: it can hold the name of a category, a post type or a post. A
  // name with a tag adds no element to the form. With no selected option, the help stays as it is.
  // A selected option with no help removes the help of the option before it.
  function _show_help(option){
    var txt_help = option.data('help'), $help = $('#select_assign_group_help', panel);
    if(!option.length) return;
    $help.empty();
    if(txt_help) $help.append($('<div class="alert alert-info"><i class="fa fa-info-circle"></i>&nbsp; </div>').append(document.createTextNode(txt_help + ' ')));
  }

  function _change_additional_select(option){
    var option_value = option.attr('value'),
      additional_options = ['_post_simple', '_category_simple'];

    for (key in additional_options) {
      if (option_value === additional_options[key]){
        $('#select'+additional_options[key], panel).show().removeAttr('disabled');
      }else{
        $('#select'+additional_options[key], panel).hide().attr('disabled','disabled');
      }
    }
  }

  function _search_group_class_name(group_class_name) {
    if (group_class_name.search("Post,") == 0) group_class_name = '_post_simple';
    if (group_class_name.search("Category_Post,") == 0) group_class_name = '_category_simple';
    return group_class_name;
  }

  function cama_custom_field_set_slug(_panel){
    $('.text-slug:not(.runned)', _panel || panel).each(function(){
      var $parent = $(this).parents('.panel-item');
      var $label = $parent.find('.span-title');
      $(this).slugify($parent.find('.text-title'), {
          slugFunc: function(str, originalFunc) {
            // The name of a field is text. A name with a tag adds no element to the form.
            $label.text(str);
            return originalFunc(str);
          }
        }
      );
      $(this).addClass('runned')
    });
  }
});