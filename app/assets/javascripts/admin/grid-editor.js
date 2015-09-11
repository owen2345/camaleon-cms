jQuery(function(){
    $.fn.fadeDestroy = function(speed){ $(this).fadeOut(speed, function(){ $(this).remove(); }) }
    $.fn.isGridEditorContent = function(str){ return str.match(/^\<p\>\[load_libraries/); } // verify is text is a content for grid editor
    $.fn.skipGridEditorLibraries = function(str){ return str.replace(/^\<p\>\[load_libraries(.*)\]\<\/p\>/, ""); } // remove libraries shortcode text from grid editor
    $.fn.gridEditor_extra_rows = [];
    $.fn.gridEditor_libraries = [];
    //********************** editor content options **********************//
    $.fn.gridEditor_options = {
        text: {title: "Text", libraries: [], callback: function(panel, editor){
            open_modal({title: "Entere Your Text", modal_settings: { keyboard: false, backdrop: "static" }, show_footer: true, content: "<textarea rows='10' class='form-control'></textarea>", callback: function(modal){
                var submit = $('<button type="button" class="btn btn-primary">Save</button>').click(function(){
                    panel.html(modal.find("textarea").val());
                    modal.modal("hide");
                    editor.trigger("auto_save");
                });
                modal.find("textarea").val(panel.html());
                modal.find(".modal-footer").prepend(submit);
            }});
        }},
        editor: {title: "Editor", libraries: [], callback: function(panel, editor){
            open_modal({title: "Entere Your Text", modal_settings: { keyboard: false, backdrop: "static" }, show_footer: true, content: "<textarea rows='10' class='form-control'></textarea>", callback: function(modal){
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
        }},
        slider: {title: "Slider", callback: function(panel, editor){
            open_modal({title: "Entere Slider Items", modal_settings: { keyboard: false, backdrop: "static" }, show_footer: true, content: "<textarea rows='10' class='form-control'></textarea>", callback: function(modal){
                var submit = $('<button type="button" class="btn btn-primary">Save</button>').click(function(){
                    panel.html(modal.find("textarea").val());
                    modal.modal("hide");
                    editor.trigger("auto_save");
                });
                modal.find("textarea").val(panel.html());
                modal.find(".modal-footer").prepend(submit);
            }});
        }},
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
                var col = $(this).removeClass("drg_column btn btn-default ui-draggable ui-draggable-handle ui-draggable-dragging ui-sortable-handle").removeAttr("style");
                col.children(".header_box").remove();
                col.find(".grid_sortable_items").children().each(function(){ //contents
                    $(this).removeClass("drg_item btn btn-default ui-draggable ui-draggable-dragging ui-sortable-handle ui-draggable-handle").removeAttr("style").children(".header_box").remove();
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
                ui.item.removeAttr('style');
                if(!jQuery(ui.item).hasClass('grid-col-built')) parse_content_column(ui.item)
                ui.item.addClass('grid-col-built');
                editor.trigger("auto_save");
            }
        });

        // column dropdown options
        jQuery('.panel_grid_body ', editor).on({
            click: function (e) {
                if(confirm(I18n("grid_editor.del_block"))) jQuery(this).closest(".drg_column").fadeDestroy();
                e.preventDefault();
            }
        }, '.grid_col_remove').on({
            click: function (e) {
                var widget = jQuery(this).closest(".drg_column");
                var widget_clone = widget.clone();
                widget.after(widget_clone);
                grid_content_manager(widget_clone.find(".grid_sortable_items"));
                e.preventDefault();
            }
        }, '.grid_col_clone');

        // content dropdown options
        jQuery('.panel_grid_body ', editor).on({
            click: function (e) {
                if(confirm(I18n("grid_editor.del_block"))) jQuery(this).closest(".drg_item").fadeDestroy();
                e.preventDefault();
            }
        }, '.drg_item .grid_content_remove').on({
            click: function (e) {
                var widget = jQuery(this).closest(".drg_item");
                var widget_clone = widget.clone();
                widget.after(widget_clone);
                e.preventDefault();
            }
        }, '.drg_item .grid_content_clone').on({
            click: function (e) {
                var panel_content = $(this).closest(".drg_item");
                var key = panel_content.attr("data-kind");
                $.fn.gridEditor_options[key]["callback"](panel_content.children(".grid_item_content"), editor);
                e.preventDefault();
            }
        }, '.drg_item .grid_content_edit');

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
                    ui.item.addClass('col-md-12').removeAttr('style');
                    if(!jQuery(ui.item).hasClass('grid-item-built')) parse_content_content(ui.item)
                    ui.item.addClass('grid-item-built');
                    editor.trigger("auto_save");
                }
            });
        }
        return textarea;
    }
});