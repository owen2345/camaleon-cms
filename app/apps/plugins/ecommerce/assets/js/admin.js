jQuery(function(){
    if($.fn.datepicker)$('#options_expirate_date').datepicker({
        format: 'yyyy-mm-dd'
    })


    if($('#tab-select-payment-method > ul a').size() > 0)
    {
        $('#tab-select-payment-method > ul a').click(function (e) {
            e.preventDefault()
            disabled_inputs(this)
            //$(this).tab('show')
        })

        function disabled_inputs(dom_a){
            var attr_id = $(dom_a).attr('href')
            $('#tab-select-payment-method .tab-content .tab-pane').find('input, select, textarea').attr('disabled', 'disabled');
            $(attr_id).find('input, select, textarea').removeAttr('disabled');
        }
        disabled_inputs($('#tab-select-payment-method > ul li.active a')[0])
    }

    $('.box-adv-search').each(function(){
        var cont = $(this);
        var rnd = "input_"+Math.floor((Math.random() * 1000000) + 1);
        cont.find('#adv-search > input').change(function(){
            cont.find('form  .' + rnd).val($(this).val());
        }).clone().attr('type','hidden').addClass(rnd).appendTo(cont.find('form'));
        cont.find('#adv-search .btn-group > button').click(function(){
            cont.find('form').submit();
        });
    })
})
