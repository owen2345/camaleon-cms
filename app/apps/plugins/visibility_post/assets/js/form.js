jQuery(function($){
    var panel = $("#panel-post-visibility");
    var link_edit = panel.find(".edit-visibility").click(function(){
        panel.find(".panel-options").removeClass("hidden").show();
        link_edit.hide();
        return false;
    });
    panel.find(".lnk_hide").click(function(){
        panel.find(".panel-options").hide();
        link_edit.show();
        return false;
    });

    panel.find("input[name='post[visibility]']").change(function(){
        var label = $(this).closest("label");
        panel.find(".visibility_label").html(label.text());
        label.siblings("div").hide();
        var rel_block = label.next().show();
        
        if($(this).val() == 'private') rel_block.find('input.visibility_private_group_item:first').addClass('required data-error-place-parent');
        else panel.find('input.visibility_private_group_item:first').removeClass('required');

        if($(this).val() == 'password') rel_block.find('input:text').addClass('required');
        else panel.find('input.password_field_value').removeClass('required');
        
    }).filter(":checked").trigger("change");

    var cal_input = $("#form-post").find('#published_from');
    cal_input.datetimepicker({format: 'YYYY-MM-DD HH:mm'});
});