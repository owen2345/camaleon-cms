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
        $("#cp_photo").parent("a").find("span").html("Choose another photo");
        var img = $("#cp_target").find("#crop_image")
        if (img.length === 1) {
            $("#cp_img_path").val(img.attr("src"));

            img.cropper({
                aspectRatio: 1,
                done: function (data) {
                    $("#ic_x").val(data.x);
                    $("#ic_y").val(data.y);
                    $("#ic_h").val(data.height);
                    $("#ic_w").val(data.width);
                }
            });

            $("#cp_accept").prop("disabled", false).removeClass("disabled");
            $("#cp_crop").css({"width": "400px", "margin": "0px auto"});
            $("#cp_crop").find('.modal-body').css({"max-height": "400px", "overflow": "auto"});
            $("#cp_accept").unbind("click").on("click", function () {
                //$("#user_image").html('<img src="/assets/loader.gif"/>');
                $("#modal_change_photo").modal("hide");
                $("#cp_crop").ajaxForm({
                    beforeSend: function () {
                        showLoading();
                    }, success: function (res) {
                        hideLoading();
                        if (res != "") $("#modal_change_password .modal-body").flash_message(res);
                        $("#user_image").html('<img class="img-thumbnail" src="' + res + '?r=' + Math.random() + '"/>');
                        hideLoading();
                    },
                    error: function(){
                        $.fn.alert({type: 'error', content: 'Internal Error', title: "Error"})
                    }
                }).submit();
                $("#cp_target").html("Use form below to upload file. Only image files.");
                $("#cp_photo").val("").parent("a").find("span").html("Select file");
                $("#cp_accept").prop("disabled", true).addClass("disabled");
                $("#cp_img_path").val("");
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
    });

});