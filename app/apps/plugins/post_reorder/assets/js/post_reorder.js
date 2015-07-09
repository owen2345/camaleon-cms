(function($){
    $.fn.reorder = function (options){
        var default_options = {url: "", table: ".table"};
        options = $.extend(default_options, options || {});

        var th_data = false;

        $(options.table+' thead tr').each(function(i, el) {

            th = $(this).find('th').attr('data-sortable');

            if(typeof th === "undefined"){
                th_data = true
            }else{
                th_data = false
            }

        });

        if(th_data){
            th_new = '<th class="center" data-sortable="0"></th>';
            $(options.table+' thead tr').prepend(th_new);

            $(options.table+' tbody tr').each(function(i, el) {
                id = $(this).attr('data-id');

                td_new = '<td>'
                            +'<div class="moved" style="cursor: all-scroll">'
                            +'<i class="fa fa-arrows"></i>'
                            +'<input type="hidden" name="values[]" value="'+id+'" />'
                            +'</div>'
                        '</td>';

                $(this).prepend(td_new);

            });
        }


        $( options.table+" tbody" ).sortable({
            axis: "y",
            placeholder: "ui-state-highlight",
            handle: ".moved",
            //items: "tr:not(.sortable)",
            items: "tr.sortable",
            start: function(event, ui) {
                ui.item.startPos = ui.item.index();

            },
            stop: function( event, ui ) {
                $.post(options.url, $(options.table+" input" ).serialize(), function(){
                    if(ui.item.startPos != ui.item.index()){
                        var $not = noty({text: 'Sorted successfully!', layout: 'topRight', type: 'success'});
                        setTimeout(function(){
                            $not.close();
                        },2000);
                    }
                });
            },
            change: function(event, ui) {
                console.log("New position: " + ui.placeholder.index());

            }
        });

        $( options.table+" tbody" ).disableSelection();
    };

})(jQuery);