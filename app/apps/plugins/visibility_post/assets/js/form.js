jQuery(function($){
    var panel = $("#panel-post-visibility");
    var link_edit = panel.find(".edit-visibility").click(function(){
        panel.find(".panel-options").removeClass("hidden").show().find('input[name="post_private_groups[]"]:first').addClass('required data-error-place-parent');
        link_edit.hide();
        return false;
    });
    panel.find(".lnk_hide").click(function(){
        panel.find(".panel-options").hide().find('input[name="post_private_groups[]"]:first').removeClass('required');
        link_edit.show();
        return false;
    });

    panel.find("input[name='post[visibility]']").change(function(){
        var label = $(this).closest("label");
        panel.find(".visibility_label").html(label.text());
        label.siblings("div").hide();
        label.next().show();
    }).click(function(){
        //var label = $(this).closest("label");
        //label.siblings("div").hide();
        //label.next().show();
    }).filter(":checked").trigger("change");

    var cal_input = $("#form-post").find('#published_from');
    cal_input.datetimepicker({format: 'YYYY-MM-DD HH:mm'});
});