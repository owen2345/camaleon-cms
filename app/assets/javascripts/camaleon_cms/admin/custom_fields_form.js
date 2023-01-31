// add actions to assign custom fields to any model selected
jQuery(function($){
  var panel = $("#cama_custom_field_form");
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
      var check = parent.find('input.destroy_check');
      if (check.length) {
          parent.hide();
          check[0].checked = true;
      } else
        parent.remove();
    }
    return false;
  });

  $('#select_assign_group', panel).change(function(){
    var option = $(this).find('option:checked');
    var txt_help = option.data('help');
    togglePostsDropdown(option.val() === '_post_simple');
    if(txt_help) txt_help = '<div class="alert alert-info"><i class="fa fa-info-circle"></i>&nbsp; ' + txt_help + ' </div>';
    $('#select_assign_group_help', panel).html(txt_help);
    $('#select_assign_group_caption', panel).val(option.parent('optgroup').attr("label") + ' ' + option.text());
  });

  $('#select_post_simple', panel).change(function(){
    var option = $(this).find('option:checked');
    var txt_help = option.data('help');
    if(txt_help) txt_help = '<div class="alert alert-info"><i class="fa fa-info-circle"></i>&nbsp; ' + txt_help + ' </div>';
    $('#select_assign_group_help', panel).html(txt_help);
    $('#select_assign_group_caption', panel).val(option.parent('optgroup').attr("label") + ': ' + option.text());
  });

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

  function applyCurrentSelected() {
    var val = $('#select_assign_group', panel).attr('data-value');
    var postOption = $('#select_post_simple', panel).find(`option[value='${val}']`).length;
    var dropdown = $('#select_assign_group', panel);
    postOption ? dropdown.val('_post_simple').trigger('change') : dropdown.val(val);
    $('#select_post_simple', panel).val(val);
  }

  function togglePostsDropdown(flag) {
    var dropdown = $('#select_post_simple', panel);
    dropdown[0].disabled = !flag;
    flag ? dropdown.show() : dropdown.hide();
  }

  applyCurrentSelected();
});