jQuery(function ($) {
    var form = $("#user_form");
    form.validate();

    $('#profie-form-ajax-password').validate({submitHandler: function(){
        showLoading();
        var form2 = $(this.currentForm);
        $.post(form2.attr("action"), form2.serialize(), function(res){
            form2.flash_message(res);
        }).complete(function(){ hideLoading(); });
        return false;
    } });


    // on success photo crop
    function onSuccess() {
        var form = $("#cp_crop");
        var img = form.find("#crop_image");
        if (img.length === 1) {
            form.find("[name='cp_img_path']").val(img.attr("src"));
            img.cropper({
                aspectRatio: 1,
                minWidth: 100,
                minHeight: 100,
                maxWidth: 200,
                maxHeight: 200,
                done: function (data) {
                    form.find("[name='ic_x']").val(data.x);
                    form.find("[name='ic_y']").val(data.y);
                    form.find("[name='ic_h']").val(data.height);
                    form.find("[name='ic_w']").val(data.width);
                }
            });

            $("#cp_accept").prop("disabled", false).unbind("click").on("click", function () {
                $("#modal_change_photo").modal("hide");
                showLoading();
                $.post(form.attr('action'), form.serialize(), function(res){
                    hideLoading();
                    $("#user_image").html('<img class="img-thumbnail" src="' + res + '?r=' + Math.random() + '"/>');
                }).error(function(){
                    $.fn.alert({type: 'error', content: 'Internal Error', title: "Error"})
                });
                $("#cp_accept").prop("disabled", true);
                $("#cp_img_path").val("");
                $("#cp_target").html("");
                return false;
            });
        }
    }

    $("#cp_photo").on("click", function () {
        $.fn.upload_filemanager({
            formats: 'image',
            selected: function (file) {
                $("#cp_target").html("<img id='crop_image' src='" + file.url + "' >");
                onSuccess()
            },
            user_pwd: '<%= current_user_pwd %>'
        });
        return false;
    });

});