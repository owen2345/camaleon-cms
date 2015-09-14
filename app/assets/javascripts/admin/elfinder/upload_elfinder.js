// options:
// - title: Title Modal, default: Upload File
// - type: image, video, audio, application/pdf,... default: 'all'
// - multiple: return array files or uniq file, default: true
//  - mode, menubar icons visibility, default: basic,  values: full, basic
// - params: in mode basic use options toolbar: default: [], example: ['resize','mkdir']
// - tree: in mode basic use, default: false
// - validate_size, resize validate, sample: 40x62
// callback: function called after imported the file on elfinder.

// elfinder for file uploads
!(function($){
    $.fn.upload_elfinder = function(options){
        var default_options = {type:"all",selected:false, mode: 'basic', params: [], tree: false, multiple: true, validate_size: false};
        options = $.extend(default_options, options);
        if(!options.locale) options.locale = CURRENT_LOCALE;

        var mime_type = options.type;

        var $content = $(this);

        var ui_opts = ['toolbar','tree', 'path', 'stat'];
        var toolbar_ui = null;
        switch (options.mode){
            case 'full':
                var cmds = [
                    'open', 'reload', 'home', 'up', 'back', 'forward', 'getfile', 'quicklook',
                    /*'download',*/ 'rm', 'duplicate', 'rename', 'mkdir', 'mkfile', 'upload', 'copy',
                    'cut', 'paste'/*, 'edit', 'extract', 'archive', 'search'*/, 'info', 'view'/*, 'help'*/,
                    'resize', 'sort'
                ]
                break;
            default:
                var cmds = [ 'rm',  'info', 'sort', 'view','upload', "resize"];
                if(options.params) cmds = cmds.concat(options.params);
                if(options.validate_size) cmds = cmds.concat(['resize']);
                toolbar_ui = [];
                if(!options.tree){
                    ui_opts = ['toolbar', 'path', 'stat', "sort"];
                }else{
                    toolbar_ui = [
                        ['home', 'up'],
                        ['back', 'forward', 'reload']
                    ];
                    cmds = cmds.concat(['open', 'reload', 'home', 'up', 'back', 'forward']);
                }
                toolbar_ui = toolbar_ui.concat([
                    ['upload','mkdir'],
                    ['info'],
                    ['rm'],
                    ['resize'],
                    ['view'],
                    ['sort']
                ]);
                break;
        }

        function hide_info(){
            $content.find('#import_button').parent().hide();
            $content.find('.content-panel-info').hide().html('');
        }

        var init_elfinder = function()
        {
            window.content_elfinder = $content.elfinder({

                url : "/admin/elfinder".to_url(), // connector URL (REQUIRED)
                lang: options.locale,
                height: '500',
                transport : new elFinderSupportVer1(),
                handlers : {
                    init   : function(event, _elfinder) {
                        $content.find('.elfinder-navbar').append('<div id="elfinder-panel-info" class="">'+
                            '<div class="body-panel">'+
                            '<div class="content-panel-info"></div>'+
                            '<div class="col-md-12" style="display: none">' +
                            (options.selected ? '<button id="import_button"  class="btn btn-primary btn-block">'+_elfinder.messages.import+'</button>' : '') +
                            '</div>'+
                            '</div>'+
                            '</div>' +
                            '<button id="upload_button"  class="btn btn-info btn-block" >'+_elfinder.messages.cmdupload+'</button>');
                        $content.find('#upload_button').unbind().click(function(){
                            $('.elfinder-button form input').click()
                            return false;
                        });

                    },
                    select : function(event, elfinderInstance) {
                        var selected = event.data.selected;

                        if (selected.length) {
                            var datas = [];
                            for(var i=0; i<selected.length;i++){
                                var file = elfinderInstance.file(selected[i]);
                                if(file.mime && (mime_type == "all" || $.inArray(true, mime_type.split(",").map(function(format){ return file.mime.indexOf(format) > -1 })) >= 0)){
                                    if(file.size > 0) datas.push(file);
                                }
                            }
                            infoFile(elfinderInstance.file(selected[0]), datas);
                            $content.find('#import_button').unbind().click(function(){
                                if(options.selected){
                                    function l_oad(datas){
                                        options.selected(options.multiple ? datas : _.first(datas));
                                        if(modal_elfinder) modal_elfinder.modal("hide");
                                    }
                                    var file = _.first(datas);
                                    if(options.validate_size){
                                        if(options.validate_size == file.dim){
                                            l_oad(datas)
                                        }else{
                                            alert("Required size: " + options.validate_size);
                                            $('.elfinder-button .elfinder-button-icon-resize').parent().click()
                                        }
                                    }else{
                                        l_oad(datas)
                                    }

                                }
                            });

                        }else{
                            hide_info()
                        }
                    },
                    dblclick : function(event, elfinderInstance) {
                        event.preventDefault();
                        elfinderInstance.exec('getfile')
                            .done(function() { elfinderInstance.exec('quicklook'); })
                            .fail(function() { elfinderInstance.exec('open'); });
                    }
                },

                getFileCallback : function(files, fm) {
                    return false;
                },

                commandsOptions : {
                    quicklook : {
                        width : 640,  // Set default width/height voor quicklook
                        height : 480
                    }
                },
                ui: ui_opts,
                uiOptions : {
                    toolbar : toolbar_ui ? toolbar_ui : [
                        ['home', 'up'],
                        ['back', 'forward'],
                        ['reload'],
                        ['mkdir', 'mkfile', 'upload'],
                        ['download', 'getfile'],
                        ['info'],
                        ['quicklook'],
                        ['copy', 'cut', 'paste'],
                        ['rm'],
                        ['duplicate', 'rename', 'edit', 'resize'],
                        ['search'],
                        ['view']
                    ]
                },
                commands : cmds
            }).elfinder('instance');
            if($.fn.tooltip) $('.elfinder-button').tooltip({placement: 'bottom'});
        };

        if($content.size()){
            var modal_elfinder = false;
            init_elfinder();
        }else{
            var html = '<div id="modal_elfinder" class="modal fade bs-example-modal-lg" tabindex="-1" role="dialog" aria-labelledby="myLargeModalLabel" aria-hidden="true">'+
                '<div class="modal-dialog modal-lg">'+
                '<div class="modal-content">'+
                '<div class="modal-header">'+
                '<button type="button" class="close" data-dismiss="modal"><span aria-hidden="true">&times;</span><span class="sr-only">Close</span></button>'+
                '<h4 class="modal-title" id="defModalHead">Media</h4>'+
                '</div>'+
                '<div id="content_elfinder"></div>'+
                '</div>'+
                '</div>'+
                '</div>';

            var modal_elfinder = $(html);
            modal_elfinder.modal();
            modal_elfinder.on('shown.bs.modal', function (e){
                $content = $('#modal_elfinder #content_elfinder');
                init_elfinder();
            });
            modal_elfinder.on('hidden.bs.modal', function (e){
                $("#modal_elfinder").remove();
            });
        }

        // ************ utils //**************/

        var infoFile = function(elemFirst, datas){
            var panelInfo = "<div class='row'><h4 class='col-md-12'>"+content_elfinder.messages.details+" <a href='#' class='btn-close text-danger pull-right'><i class='ui-icon ui-icon-circle-close'></i></a> </h4></div>"+
                "<div id='panel-info-title' class='row'>"+
                "<div class='image col-md-4'>"+imageFile(elemFirst)+"</div>"+
                "<div class='detail col-md-8'>"+
                "<strong>"+elemFirst.name+"</strong>"+"<br>"+
                "<span>"+elemFirst.mime+"</span>"+
                "</div>"+
                "</div>"+
                "<div id='panel-info-content' class='row'>"+
                "<p class='col-md-12'>"+content_elfinder.messages.size+" : <span>"+content_elfinder.formatSize(elemFirst.size)+"</span></p>"+
                "<p class='col-md-12'>URL : <span><input type='text' onClick='this.select();' value='"+elemFirst.url.to_url()+"' /></span></p>"+
                (is_image_data(elemFirst) ? "<p class='col-md-12'>"+content_elfinder.messages.thumb+" : <span><input type='text' onClick='this.select();' value='"+ (elemFirst.tmb != "1" ? elemFirst.tmb.toString().to_url() : elemFirst.url.to_url()) +"' /></span></p>" : "")+
                "<p class='col-md-12'>"+content_elfinder.messages.dim+" :  <span>"+elemFirst.dim+"</span></p>"+
                "<p class='col-md-12'>"+content_elfinder.messages.modify+"  :  <span>"+elemFirst.date.replace('-0400','')+"</span></p>"+
                "</div>";

            $content.find('.content-panel-info').show().html(panelInfo);
            $content.find('.content-panel-info .btn-close').unbind().click(function(){
                hide_info()
                return false;
            });
            if($.inArray(elemFirst, datas) >= 0)
                $content.find('#import_button').parent().show();
            else
                $content.find('#import_button').parent().hide();
        };

        var imageFile = function (datas){
            if(is_image_data(datas)){
                //return "<img title='"+datas.name+"' style='width: 100%' src='"+datas.url+'?q='+ Math.random() +"'>";
                return "<img title='"+datas.name+"' style='width: 100%' src='"+(datas.tmb == "1" ? datas.url : datas.tmb)+"'>";

            }else{
                return '<div class="elfinder-cwd-file-wrapper ui-corner-all ui-draggable ui-draggable-handle ui-state-hover">'+
                    '<div class="elfinder-cwd-icon elfinder-cwd-icon-application ui-corner-all '+content_elfinder.mime2class(datas.mime)+'" unselectable="on"></div>'+
                    '</div>';
            }
        };
        // check if datas is image format
        function is_image_data(datas){ return datas.mime && datas.mime.indexOf("image") > -1 }
    }
})(jQuery);