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
        label.next().show();
    }).click(function(){
        //var label = $(this).closest("label");
        //label.siblings("div").hide();
        //label.next().show();
    }).filter(":checked").trigger("change");

    var cal_input = $('#datetimepicker');
    cal_input.datepicker({
        language: CURRENT_LOCALE
    });
});