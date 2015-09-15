jQuery(function(){
    $.fn.fadeDestroy = function(speed){ $(this).fadeOut(speed, function(){ $(this).remove(); }) }
    $.fn.isGridEditorContent = function(str){ return str.match(/^\<p\>\[load_libraries/); } // verify is text is a content for grid editor
    $.fn.skipGridEditorLibraries = function(str){ return str.replace(/^\<p\>\[load_libraries(.*)\]\<\/p\>/, ""); } // remove libraries shortcode text from grid editor
    $.fn.gridEditor_extra_rows = [];
    $.fn.gridEditor_libraries = [];
    //********************** editor content options **********************//
    $.fn.gridEditor_options = {
        text: {title: "Text", libraries: [], callback: grid_text_builder},
        editor: {title: "Editor", libraries: [], callback: grid_editor_builder},
        tab: {title: "Tabs", callback: grid_tab_builder},
        slider: {title: "Slider", callback: grid_slider_builder},
    };
    //********************** end editor content options **********************//

    // grid editor plugin
    var gridEditor_id = 0;
    $.fn.gridEditor = function(tinyEditor){
        gridEditor_id ++;
        var tinymce_panel = $(tinyEditor.editorContainer).hide();
        var editor_id = "grid_editor_"+gridEditor_id;
        var textarea = $(this);
        if(textarea.prev().hasClass("panel_grid_editor")){ textarea.prev().show(); return textarea; }
        var tpl_rows = "";
        $.each({6: 50, 4: 33, 3: 25, 2: 16, 8: 66, 9: 75, 12: 100}, function(k, val){ tpl_rows += '<div class="" data-col="'+k+'" data-col_title="'+val+'%"><div class="grid_sortable_items"></div></div>'; });

        // break line
        tpl_rows += '<div class="clearfix" data-col_title="Break Line" data-col="12"></div>' + $.fn.gridEditor_extra_rows.join("");

        // tpl options
        var tpl_options = "";
        $.each($.fn.gridEditor_options, function(key, item){ tpl_options += '<div class="" data-kind="'+key+'" data-content_title="'+item["title"]+'"><div class="grid_item_content"></div></div>'; });

        // template grid editor
        var editor = $("<div class='panel_grid_editor' id='"+editor_id+"'>"+
            "<div class='grid_editor_menu'>"+
            "<ul class='nav nav-tabs'>"+
            "<li class='active'><a href='#grid_columns_"+gridEditor_id+"' role='tab' data-toggle='tab'>"+I18n("grid_editor.blocks")+"</a></li>"+
            "<li class=''><a href='#grid_contents_"+gridEditor_id+"' role='tab' data-toggle='tab'>"+I18n("grid_editor.contents")+"</a></li>"+
            "<li class=''><a class='btn btn-default clear'>"+I18n("grid_editor.clear")+"</a></li>"+
            '<li>' +
            '<a class = "btn btn-default dropdown-toggle" type="button" data-toggle="dropdown" aria-haspopup="true" aria-expanded="false">'+I18n("grid_editor.templates")+' <span class="caret"></span> </a>'+
            '<ul class="dropdown-menu" aria-labelledby="dropdownMenu1"> ' +
            '<li><a class="list_templates" title="Grid Templates" href = "'+root_url+'/admin/grid_editor" >'+I18n("grid_editor.list")+'</a></li >'+
            '<li><a class="new_template" title="New Template" href = "'+root_url+'/admin/grid_editor/new" >'+I18n("grid_editor.save_tpl")+'</a></li >'+
            '</ul> ' +
            '</li>'+
            "<li class=''><a href='#' class='toggle_panel_grid'>"+I18n("grid_editor.text_editor")+"</a></li>"+
            "</ul>"+
            "<div class='tab-content'>"+
            "<div role='tabpanel' class='tab-pane active' id='grid_columns_"+gridEditor_id+"'> "+tpl_rows+" </div>"+
            "<div role='tabpanel' class='tab-pane' id='grid_contents_"+gridEditor_id+"'>"+tpl_options+"</div>"+
            "</div>"+
            "</div>"+
            "<div class='panel_grid_body row'></div>"+
            "</div>");

        // grid editor export
        function export_content(editor){
            var container = $('.panel_grid_body', editor).clone();
            container.children().each(function(){
                var col = $(this).removeClass("drg_column btn btn-default ui-draggable ui-draggable-handle ui-draggable-dragging ui-sortable-handle");
                col.children(".header_box").remove();
                col.find(".grid_sortable_items").children().each(function(){ //contents
                    $(this).removeClass("drg_item btn btn-default ui-draggable ui-draggable-dragging ui-sortable-handle ui-draggable-handle").children(".header_box").remove();
                });
            });
            var res = container.html();
            container.remove();
            return res;
        }

        // grid editor parser to recover from saved content
        function parse_content(editor){
            editor.find(".panel_grid_body").children("div").each(function(){ var col = parse_content_column($(this)); });
            return editor;
        }

        // parse column editor
        // column: content element
        // skip_options: boolean to add drodown options
        function parse_content_column(column, skip_options){
            var html = '<div class="header_box">'+
                '<a><i class="icon-bar"></i>'+column.attr("data-col_title")+'</a>'+
                '</div>';
            var options = "<div class='dropdown'>" +
                "<a class='dropdown-toggle' data-toggle='dropdown'>&nbsp; <span class='caret'></span></a>" +
                "<ul class='dropdown-menu auto_with' role='menu'>"+
                "<li><a class='grid_col_remove' title='Remove' href='#'><i class='fa fa-trash-o'></i> "+I18n("button.delete")+"</a></li>"+
                "<li><a class='grid_col_clone' title='Clone' href='#'><i class='fa fa-copy'></i> "+I18n("button.clone")+"</a></li>"+
                "</ul>"+
                "</div>" ;
            column.addClass("drg_column btn btn-default");
            if(column.children(".header_box").length == 0) column.prepend(html);
            if(!skip_options){
                column.find('.header_box').append(options);
                grid_content_manager(column.find(".grid_sortable_items"));
                column.find(".grid_sortable_items").children().each(function(){ //contents
                    parse_content_content($(this));
                });
            }
            column;
        }

        // parse column editor
        // content: content element
        // skip_options: boolean to add drodown options
        function parse_content_content(content, skip_options){
            var html = '<div class="header_box">'+
                '<a><i class="icon-bar"></i>'+content.attr("data-content_title")+'</a>'+
                '</div>';
            var options = "<div class='dropdown'>" +
                "<a class='dropdown-toggle' data-toggle='dropdown'>&nbsp; <span class='caret'></span></a>" +
                "<ul class='dropdown-menu auto_with' role='menu'>"+
                "<li><a class='grid_content_remove' title='Remove' href='#'><i class='fa fa-trash-o'></i> "+I18n("button.delete")+"</a></li>"+
                "<li><a class='grid_content_clone' title='Clone' href='#'><i class='fa fa-copy'></i> "+I18n("button.clone")+"</a></li>"+
                "<li><a class='grid_content_edit' title='Edit' href='#'><i class='fa fa-pencil'></i> "+I18n("button.edit")+"</a></li>"+
                "</ul>"+
                "</div>";
            content.addClass("drg_item btn btn-default");
            if(content.children(".header_box").length == 0) content.prepend(html);
            if(!skip_options){
                content.find('.header_box').append(options);
            }
            // save used libraries
            $.fn.gridEditor_libraries = $.merge($.fn.gridEditor_libraries, $.fn.gridEditor_options[content.attr("data-kind")])
            content;
        }

        // add editor menu actions
        function do_editor_menus(editor){
            // toggle editor menus
            editor.find(".grid_editor_menu .toggle_panel_grid").click(function(){
                if(!confirm(I18n("grid_editor.toggle_editor"))) return false;
                editor.hide();
                if(editor.data("tiny_backup")) tinyEditor.setContent(editor.data("tiny_backup"));
                tinymce_panel.show();
                return false;
            });
            editor.find(".grid_editor_menu .clear").click(function(){
                if(!confirm(I18n("grid_editor.clear_editor"))) return false;
                editor.find(".panel_grid_body").html("");
                editor.trigger("auto_save");
                return false;
            })
            editor.find(".grid_editor_menu .list_templates").ajax_modal({callback: function(modal){
                modal.on("click", ".import_item", function(){
                    if(!confirm($(this).attr("data-message"))) return;
                    modal.modal("hide");
                    showLoading();
                    $.get($(this).attr("href"), function(res){
                        //editor.children(".panel_grid_body").html(res);
                        editor.children(".panel_grid_body").html($.fn.skipGridEditorLibraries(res));
                        parse_content(editor); // recover saved content
                        editor.trigger("auto_save");
                        hideLoading();
                    });
                    return false;
                });
            }});

            editor.find(".grid_editor_menu .new_template").ajax_modal({callback: function(modal){
                modal.find("textarea").val(export_content(editor));
            }});

            editor.find("#grid_columns_"+gridEditor_id).children().each(function(){ parse_content_column($(this), true) });
            editor.find("#grid_contents_"+gridEditor_id).children().each(function(){ parse_content_content($(this), true) });

            // if saved content is a grid_editor content, then rebuilt or recover this content
            if($.fn.isGridEditorContent(textarea.val())){
                editor.children(".panel_grid_body").html($.fn.skipGridEditorLibraries(textarea.val()));
                parse_content(editor); // recover saved content
            }else{
                editor.data("tiny_backup", tinyEditor.getContent())
            }

            // trigger auto save changes
            editor.bind("auto_save", function(){
                var txt = "<p>[load_libraries '"+$.fn.gridEditor_libraries.join(",")+"']</p>"+export_content($(this));
                tinyEditor.setContent(txt);
                textarea.val(txt).trigger("change_in");
            });

            // content dropdown options
            jQuery('.panel_grid_body ', editor).on("click", '.drg_item .grid_content_remove', function (e) {
                    if(confirm(I18n("grid_editor.del_block"))) {
                        jQuery(this).closest(".drg_item").fadeDestroy();
                        editor.trigger("auto_save");
                    }
                    e.preventDefault();
                }).on("click", '.drg_item .grid_content_clone', function (e) {
                    var widget = jQuery(this).closest(".drg_item");
                    var widget_clone = widget.clone();
                    widget.after(widget_clone);
                    editor.trigger("auto_save");
                    e.preventDefault();
                }).on("click", '.drg_item .grid_content_edit', function (e) {
                    var panel_content = $(this).closest(".drg_item");
                    var key = panel_content.attr("data-kind");
                    $.fn.gridEditor_options[key]["callback"](panel_content.children(".grid_item_content"), editor);
                    e.preventDefault();
                });

            // column dropdown options
            jQuery('.panel_grid_body ', editor).on("click", '.grid_col_remove', function (e) {
                    if(confirm(I18n("grid_editor.del_block"))){
                        jQuery(this).closest(".drg_column").fadeDestroy();
                        editor.trigger("auto_save");
                    }
                    e.preventDefault();
                }).on("click", '.grid_col_clone', function (e) {
                    var widget = jQuery(this).closest(".drg_column");
                    var widget_clone = widget.clone();
                    widget.after(widget_clone);
                    grid_content_manager(widget_clone.find(".grid_sortable_items"));
                    editor.trigger("auto_save");
                    e.preventDefault();
                });

            //// autosave changes
            //var time_control;
            //$('.panel_grid_body', editor).bind("DOMSubtreeModified",function(){
            //    var thiss = $(this);
            //    if(time_control) clearTimeout(time_control);
            //    time_control = setTimeout(function(){ editor.trigger("auto_save"); }, 5000);
            //});
        }

        do_editor_menus(editor);
        textarea.before(editor);

        // drag columns
        jQuery(".grid_editor_menu .drg_column", editor).draggable({
            connectToSortable: "#"+editor_id+" .panel_grid_body",
            cursor: 'move',          // sets the cursor apperance
            revert: 'invalid',       // makes the item to return if it isn't placed into droppable
            revertDuration: -1,     // duration while the item returns to its place
            opacity: 1,           // opacity while the element is dragged
            helper: "clone"
        });

        //draggable content elements
        jQuery(".grid_editor_menu .drg_item", editor).draggable({
            connectToSortable: "#"+editor_id+" .grid_sortable_items",
            cursor: 'move',          // sets the cursor apperance
            revert: 'invalid',       // makes the item to return if it isn't placed into droppable
            revertDuration: -1,     // duration while the item returns to its place
            opacity: 1,           // opacity while the element is dragged
            helper: "clone"
        });

        // Sort the parents
        jQuery(".panel_grid_body", editor).sortable({
            tolerance: "pointer",
            cursor: "move",
            revert: false,
            delay: 150,
            dropOnEmpty: true,
            items: ".drg_column",
            connectWith: "#"+editor_id+" .panel_grid_body",
            placeholder: "placeholder",
            start: function (e, ui) {
                ui.helper.css({'width': '' , 'height': ''}).addClass('col-md-' + jQuery(ui.helper).attr('data-col'));
                ui.placeholder.attr('class', jQuery(ui.helper).attr("class")).html(ui.helper.html()).fadeTo("fast", 0.4);
            },
            over: function (e, ui) {
                ui.placeholder.attr('class', jQuery(ui.helper).attr("class"));
                $(this).addClass("hover-grid");
            },
            out: function (e, ui) {
                $(this).removeClass("hover-grid");
            },
            stop: function (e, ui) {
                ui.item.css({left: "", top: "", position: ""});
                if(!jQuery(ui.item).hasClass('grid-col-built')) parse_content_column(ui.item)
                ui.item.addClass('grid-col-built');
                editor.trigger("auto_save");
            }
        });

        function grid_content_manager(item) {
            // Sort the children (content elements)
            jQuery(item).sortable({
                tolerance: "pointer",
                cursor: "move",
                revert: false,
                delay: 150,
                dropOnEmpty: true,
                items: ".drg_item",
                connectWith: "#"+editor_id+' .grid_sortable_items',
                placeholder: "placeholder",
                start: function (e, ui) {
                    ui.helper.css({'width': '' , 'height': ''}).addClass('col-md-12');
                    ui.placeholder.attr('class', jQuery(ui.helper).attr("class")).html(ui.helper.html()).fadeTo("fast", 0.4);
                },
                over: function (e, ui) {
                    $(this).addClass("hover-grid");
                },
                out: function (e, ui) {
                    $(this).removeClass("hover-grid");
                },
                stop: function (e, ui) {
                    ui.item.addClass('col-md-12').css({left: "", top: "", position: ""});
                    if(!jQuery(ui.item).hasClass('grid-item-built')) parse_content_content(ui.item)
                    ui.item.addClass('grid-item-built');
                    editor.trigger("auto_save");
                }
            });
        }
        return textarea;
    }

    // grid content tab builder
    function grid_tab_builder(panel, editor){
        var id_tab = "tabs_" + gridEditor_id + Math.floor((Math.random() * 100000) + 1);
        var tpl_tabs = '<ul class="nav nav-tabs" role="tablist">'+
            '<li role="presentation" class="active"><a href="" role="tab" data-toggle="tab">Sample1</a></li>'+
            '</ul>'+
            '<div class="tab-content">'+
            '<div role="tabpanel" class="tab-pane active" id="">Lorem Ipsum</div>'+
            '</div>';
        if(panel.html()) tpl_tabs = panel.html();
        function tab_builder(modal){
            modal.find(".nav-tabs li").not(".tb_built").addClass("tb_built").find("a").each(function(){
                var settings = "<i class='fa fa-trash-o grid_tab_del'></i>"+
                    "<i class='fa fa-pencil grid_tab_edit'></i>";
                $(this).append(settings);
            });
            var k = id_tab+'_item';
            modal.find(".nav-tabs li").each(function(index, item){
                var k_i = k+"-"+index;
                $(this).children("a").attr("href", "#"+k_i);
                modal.find(".tab-pane").eq(index).attr("id", k_i);
            });
        }
        open_modal({title: "Enter Slider Items", modal_settings: { keyboard: false, backdrop: "static" }, show_footer: true, content: tpl_tabs, callback: function(modal){
            var p_title = modal.find(".nav-tabs");
            var p_content = modal.find(".tab-content");
            p_title.append("<a href='#' class='grid_tab_add pull-right' title='Add Tabs'><i class='fa fa-plus-circle'></i> "+I18n("button.add")+"</a>")
                .on("click", ".grid_tab_add", function(e){
                    p_title.append('<li role="presentation"><a href="" role="tab" data-toggle="tab">Sample</a></li>');
                    p_content.append('<div role="tabpanel" class="tab-pane" id="">Lorem Ipsum</div>');
                    tab_builder(modal);
                    e.preventDefault();
                }).on("click", ".grid_tab_edit", function(e){
                    var title = $(this).closest("a");
                    var content = $($(this).closest("a").attr("href"));
                    var tpl = '<div class="form-group">'+
                        '<label>Title</label><br>'+
                        "<input type='text' class='form-control required'/>"+
                        "</div>"+
                        '<div class="form-group">'+
                        '<label>Content</label><br>'+
                        "<textarea rows='10' class='form-control'></textarea>"+
                        "</div>"
                    open_modal({title: "Enter Your Tab Content", modal_settings: { keyboard: false, backdrop: "static" }, show_footer: true, content: tpl, callback: function(modal){
                        var submit = $('<button type="button" class="btn btn-primary">Save</button>').click(function(){
                            title.html(title.find("i")).prepend(modal.find("input").val());
                            modal.find("input").val();
                            var area = modal.find("textarea");
                            content.html(area.tinymce().getContent());
                            modal.modal("hide");
                        });
                        modal.find("input").val(title.text());
                        modal.find("textarea").val(content.html());
                        setTimeout(function(){ modal.find("textarea").tinymce($.extend({} ,DATA.tiny_mce.advanced, {height: 120})); }, 500);
                        modal.find(".modal-footer").prepend(submit);
                    }});

                    e.preventDefault();
                }).on("click", ".grid_tab_del", function(e){
                    if(confirm("are you sure?")){
                        $($(this).closest("a").attr("href")).remove();
                        $(this).closest("li").fadeDestroy();
                    }
                    e.preventDefault();
                }).sortable({items: "> li"});
            tab_builder(modal);

            // save contents of tab
            var submit = $('<button type="button" class="btn btn-primary">Save</button>').click(function(){
                modal.find(".modal-body").find(".tb_built").removeClass("tb_built ui-sortable-handle").end().find(".nav-tabs").find(".fa, .grid_tab_add").remove();
                panel.html(modal.find(".modal-body").html());
                modal.modal("hide");
                editor.trigger("auto_save");
            });
            modal.find("textarea").val(panel.html());
            modal.find(".modal-footer").prepend(submit);
        }});
    }

    // grid content tab builder
    function grid_slider_builder1(panel, editor){
        var tpl_slider = '<div class="carousel slide" data-ride="carousel"> ' +
            '<ol class="carousel-indicators"></ol>' +
            '<div class="carousel-inner"></div>'+
            '<a class="left carousel-control" href="#'+id_slider+'" role="button" data-slide="prev"><span class="glyphicon glyphicon-chevron-left"></span></a>'+
            '<a class="right carousel-control" href="#'+id_slider+'" role="button" data-slide="next"><span class="glyphicon glyphicon-chevron-right"></span></a>'+
            '</div>';
        if(panel.html()) tpl_slider = panel.html();
        tpl_slider = $(tpl_slider);
        var form_slider = $('<form></form>').on("click", ".add_item", function(e){
            add_item();
            e.preventDefault();
        }).on("click", ".item_del", function(){
            if(confirm("are you sure?")) $(this).closest(".well").fadeDestroy();
            e.preventDefault();
        });

        function add_item(descr, url){
            var settings = "<div class='slider_actions text-center'><a href='#' class='item_del'><i class='fa fa-trash-o'></i></a></div>";
            var tpl = $('<div class="well">'+settings+'<div class="form-group"><label>Background: </label><br><input name="url_file"></div></div> <div class="form-group"><label>Description: </label><br><textarea class="descr"></textarea></div>');
            tpl.find("input").val(url);
            tpl.find("textarea").val(descr);
            form_slider.append(tpl);
        }
        tpl_slider.find(".carousel-inner").children().each(function(){ add_item($(this)); })
        if(form_slider.children("well").length == 0) form_slider.find(".add_item").click();
        open_modal({title: "Enter Slider Items", modal_settings: { keyboard: false, backdrop: "static" }, show_footer: true, content: form_slider, callback: function(modal){

            var submit = $('<button type="button" class="btn btn-primary">Save</button>').click(function(){
                modal.find(".grid_slider_settings, .slider_actions").remove();
                panel.html(modal.find(".modal-body").html());
                modal.modal("hide");
                editor.trigger("auto_save");
            });
            modal.find(".modal-footer").prepend(submit);
        }});
    }

    // manage sliders of the grid editor
    // permit to add, edit
    function grid_slider_builder(panel, editor){
        var id_slider = "slider_" + gridEditor_id + Math.floor((Math.random() * 100000) + 1);
        var tpl_slider = '<div class="carousel slide" data-ride="carousel"> ' +
                '<ol class="carousel-indicators"></ol>' +
                '<div class="carousel-inner"></div>'+
                '<a class="left carousel-control" href="#'+id_slider+'" role="button" data-slide="prev"><span class="glyphicon glyphicon-chevron-left"></span></a>'+
                '<a class="right carousel-control" href="#'+id_slider+'" role="button" data-slide="next"><span class="glyphicon glyphicon-chevron-right"></span></a>'+
            '</div>';
        if(panel.html()) tpl_slider = panel.html();
        open_modal({title: "Enter Slider Items", modal_settings: { keyboard: false, backdrop: "static" }, show_footer: true, content: tpl_slider, callback: function(modal){
            var slide = modal.find(".carousel").attr("id", id_slider);
            slide.find(".carousel-control").attr("href", "#"+id_slider).end().find(".carousel-indicators li").attr("data-target", "#"+id_slider);
            slide.before("<div class='grid_slider_settings'><a href='#' class='grid_slider_add' title='Add Slider'><i class='fa fa-plus-circle'></i> "+I18n("button.add")+"</a></div>");
            modal.on("click", ".grid_slider_add", function(e){
                    modal.find(".carousel-inner").append('<div class="item active" style="max-width: 100%;"><img src="http://www.diario-de-un-escalador.com/wp-content/uploads/Escalada20.jpg"><div class="carousel-caption">Caption here</div></div>');
                    slider_builder(modal);
                    e.preventDefault();
                }).on("click", ".grid_slide_edit", edit_slide).on("click", ".grid_slide_del", function(e){
                    if(confirm("are you sure?")){
                        $(this).closest(".item").remove();
                        slider_builder(modal);
                    }
                    e.preventDefault();
                });
            slider_builder(modal);
            if(modal.find(".carousel-inner .item").length == 0) modal.find(".grid_slider_add").click();
            // save contents of tab
            var submit = $('<button type="button" class="btn btn-primary">Save</button>').click(function(){
                modal.find(".grid_slider_settings, .slider_actions").remove();
                panel.html(modal.find(".modal-body").html());
                modal.modal("hide");
                editor.trigger("auto_save");
            });
            modal.find(".modal-footer").prepend(submit);
        }});

        // manage slide editor form
        function edit_slide(e){
            var content = $(this).closest(".item").find(".carousel-caption");
            var image = $(this).closest(".item").children("img");
            var tpl = '<div class="form-group"><label>Background: </label><br><input type="hidden" class="form-control" name="url_file"></div><div class="form-group"><label>Description: </label><br><textarea class="descr"></textarea></div>';
            open_modal({title: "Enter Your Slider Content", modal_settings: { keyboard: false, backdrop: "static" }, show_footer: true, content: tpl, callback: function(modal){
                var submit = $('<button type="button" class="btn btn-primary">Save</button>').click(function(){
                    content.html(modal.find("textarea").tinymce().getContent());
                    image.attr("src", modal.find("input").val());
                    modal.modal("hide");
                });
                modal.find("textarea").val(content.html());
                modal.find("input").val(image.attr("src")).input_upload();
                setTimeout(function(){ modal.find("textarea").tinymce($.extend({} ,DATA.tiny_mce.advanced, {height: 120})); }, 500);
                modal.find(".modal-footer").prepend(submit);
            }});

            e.preventDefault();
        }

        // slider options and update indicators
        function slider_builder(modal){
            var slide = modal.find(".carousel");
            var indi = modal.find(".carousel-indicators").html("");
            var settings = "<div class='slider_actions text-center'><a href='#' class='grid_slide_del'><i class='fa fa-trash-o'></i></a> <a href='#' class='grid_slide_edit'><i class='fa fa-pencil'></i></a></div>";
            modal.find(".carousel-inner").children().each(function(index, item){
                indi.append('<li data-target="#'+id_slider+'" data-slide-to="'+index+'"></li>');
                if($(this).find(".slider_actions").length == 0) $(this).append(settings);
            });
            var act = modal.find(".carousel-inner .item.active:last").index();
            modal.find(".carousel-indicators li").removeClass("active").eq(act).addClass("active");
            modal.find(".carousel-inner .item").removeClass("active").eq(act).addClass("active");
        }
    }

    // grid content editor builder
    function grid_editor_builder(panel, editor){
        open_modal({title: "Enter Your Content", modal_settings: { keyboard: false, backdrop: "static" }, show_footer: true, content: "<textarea rows='10' class='form-control'></textarea>", callback: function(modal){
            var submit = $('<button type="button" class="btn btn-primary">Save</button>').click(function(){
                var area = modal.find("textarea");
                panel.html(area.tinymce().getContent());
                modal.modal("hide");
                editor.trigger("auto_save");
            });
            modal.find("textarea").val(panel.html());
            setTimeout(function(){ modal.find("textarea").tinymce($.extend({} ,DATA.tiny_mce.advanced, {height: 120})); }, 500);
            modal.find(".modal-footer").prepend(submit);
        }});
    }

    // grid content text builder
    function grid_text_builder(panel, editor){
        open_modal({title: "Enter Your Text", modal_settings: { keyboard: false, backdrop: "static" }, show_footer: true, content: "<textarea rows='10' class='form-control'></textarea>", callback: function(modal){
            var submit = $('<button type="button" class="btn btn-primary">Save</button>').click(function(){
                panel.html(modal.find("textarea").val());
                modal.modal("hide");
                editor.trigger("auto_save");
            });
            modal.find("textarea").val(panel.html());
            modal.find(".modal-footer").prepend(submit);
        }});
    }

});