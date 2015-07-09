jQuery(function(){
    if($('#table-shopping-cart td .text-qty').size() > 0)
    {
        $('#table-shopping-cart td .text-qty').change(function(){
            if ($(this).val() < 1) return false;
            var total = $('#table-shopping-cart tbody tr').map(function(){
                var $tr = $(this);
                var price = parseFloat($tr.find('td[data-price]').attr('data-price'));
                var tax =  parseFloat($tr.find('td[data-tax]').attr('data-tax'));
                var qty =  parseFloat($tr.find('td[data-qty] input.text-qty').val());
                if(qty < 0) qty = 0;
                var subtotal = (price + tax) * qty;
                $tr.find('td[data-subtotal]').html('$'+subtotal.toFixed(2))
                return subtotal;
            }).get().reduce(function(a, b) { return a + b; }, 0);

            $('#table-shopping-cart #total').html('$'+total.toFixed(2))
        })
    }
    $('#checkout #copy').click(function(){
        $('#checkout #shipping_address').find('input, select, textarea').each(function(){
            var id_from = $(this).attr('id').replace('order_shipping', 'order_billing');
            $(this).val($('#billing_address #'+id_from).val())
        })
        return false;
    });

    if($('#e-payments-types > ul a').size() > 0)
    {
        $('#e-payments-types > ul a').click(function (e) {
            e.preventDefault()
            disabled_inputs(this)
            //$(this).tab('show')
        })

        function disabled_inputs(dom_a){
            var attr_id = $(dom_a).attr('href')
            $('#e-payments-types .tab-content .tab-pane').find('input, select, textarea').attr('disabled', 'disabled');
            $(attr_id).find('input, select, textarea').removeAttr('disabled');
        }
        disabled_inputs($('#e-payments-types > ul a')[0])
    }

    function set_total_amount(){
        var value = parseFloat($('#checkout #shipping_methods option:checked').attr('data-price'));
        var pre_total = parseFloat($('#checkout #order_total').attr('data-total'));
        $('#checkout #shipping_total span').html(value.toFixed(2));
        var total_final = (value + pre_total).toFixed(2);
        $('#checkout #order_total span').html(total_final);
    }

    $('#checkout #shipping_methods').change(function(){
        set_total_amount()
    });

    $('#checkout #e_coupon_apply_box button').click(function(){
        var href = $('#e_coupon_apply_box').attr('data-href');
        var token = $('#e_coupon_apply_box').attr('data-token');
        var code = $('#e_coupon_apply_box .coupon-text').val();
        $.post(href, {code: code, authenticity_token: token}, function(res){
            if(res.error){
                alert(res.error)
            }else{
                $('#checkout #coupon_application_row').show().find('#coupon_application_total span').html(res.data.text)
                $('#checkout #coupon_code').val(res.data.code)
                $('#checkout #coupon_options').val(JSON.stringify(res.data.options))
                set_total_amount()
            }
            log(res)
        }, 'json')
    });


    // pay by credit card
    var card_valid = false;
    var $form = $('#payment-form');
    if($form.size() > 0){
        /* If you're using Stripe for payments */
        function payWithStripe(e) {
            // e.preventDefault();

            /* Visual feedback */
            $form.find('[type=submit]').html('Validating <i class="fa fa-spinner fa-pulse"></i>');

            if(!card_valid)
            {
                /* Visual feedback */
                $form.find('[type=submit]').html('Try again');
                /* Show Stripe errors on the form */
                $form.find('.payment-errors').text("Credit Card Invalid");
                $form.find('.payment-errors').closest('.row').show();
                return false
            }else{
                if($form.valid()){
                    /* Visual feedback */
                    $form.find('[type=submit]').html('Processing <i class="fa fa-spinner fa-pulse"></i>');
                    /* Hide Stripe errors on the form */
                    $form.find('.payment-errors').closest('.row').hide();
                    $form.find('.payment-errors').text("");
                }else{
                    return false;
                }
            }
        }

        $form.on('submit', payWithStripe);
        $form.find('input[name="cardNumber"]').validateCreditCard(function(result) {
            card_valid = result.valid;
            // $('#credit_card_log').html('Card type: ' + (result.card_type == null ? '-' : result.card_type.name) + (result.valid ? '<span class="label label-success">Valid</span>' : '<span class="label label-danger">Not Valid</span>'))
        });

        /* Form validation */
        jQuery.validator.addMethod("month", function(value, element) {
            return this.optional(element) || /^(01|02|03|04|05|06|07|08|09|10|11|12)$/.test(value);
        }, "Please specify a valid 2-digit month.");

        jQuery.validator.addMethod("year", function(value, element) {
            return this.optional(element) || /^[0-9]{2}$/.test(value);
        }, "Please specify a valid 2-digit year.");

        validator = $form.validate({
            rules: {
                cardNumber: {
                    required: true,
                    creditcard: true,
                    digits: true
                },
                expMonth: {
                    required: true,
                    month: true
                },
                expYear: {
                    required: true,
                    year: true
                },
                cvCode: {
                    required: true,
                    digits: true
                }
            },
            highlight: function(element) {
                $(element).closest('.form-control').removeClass('success').addClass('error');
            },
            unhighlight: function(element) {
                $(element).closest('.form-control').removeClass('error').addClass('success');
            },
            errorPlacement: function(error, element) {
                $(element).closest('.form-group').append(error);
            }
        });

        paymentFormReady = function() {
            if ($form.find('[name=cardNumber]').hasClass("success") &&
                $form.find('[name=expMonth]').hasClass("success") &&
                $form.find('[name=expYear]').hasClass("success") &&
                $form.find('[name=cvCode]').val().length > 1) {
                return true;
            } else {
                return false;
            }
        }

        $form.find('[type=submit]').prop('disabled', true);
        var readyInterval = setInterval(function() {
            if (paymentFormReady()) {
                $form.find('[type=submit]').prop('disabled', false);
                clearInterval(readyInterval);
            }
        }, 250);
    }


})
function log(d){
    console.log(d)
}