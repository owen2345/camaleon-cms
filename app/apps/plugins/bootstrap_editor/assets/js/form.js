jQuery(function($){
    DATA.tiny_mce.advanced["style_formats_merge"] = true;
    DATA.tiny_mce.advanced["style_formats"] = [

        // buttons
        {
            title: 'Bootstrap Buttons Size',
            items: [
                { title: 'Large', selector: '.btn', classes: "btn-lg" },
                { title: 'Small', selector: '.btn', classes: "btn-sm" },
                { title: 'Extra Small', selector: '.btn', classes: "btn-xs" },
                { title: 'Block', selector: '.btn', classes: "btn-block" },
                { title: 'Disabled', selector: '.btn', classes: "disabled" },
                { title: 'Badge', inline: 'span', classes: "badge" }
            ]},

        // panels
        {
            title: 'Bootstrap Panels',
            items: [
                { title: 'Primary', selector: '.panel', attributes: {class: "panel panel-primary"} },
                { title: 'Success', selector: '.panel', attributes: { class: "panel panel-success" } },
                { title: 'Info', selector: '.panel', attributes: { class: "panel panel-info" } },
                { title: 'Warning', selector: '.panel', attributes: { class: "panel panel-warning" } },
                { title: 'Danger', selector: '.panel', attributes: { class: "panel panel-danger" } }
            ]},

        // alerts
        {
            title: 'Bootstrap Alerts',
            items: [
                { title: 'Success', selector: '.alert', attributes: {class: 'alert alert-success'}},
                { title: 'Info', selector: '.alert', attributes: {class: 'alert alert-info'}},
                { title: 'Warning', selector: '.alert', attributes: {class: 'alert alert-warning'}},
                { title: 'Danger', selector: '.alert', attributes: {class: 'alert alert-danger'}},
            ]},

        // button groups
        {
            title: 'Bootstrap Button Groups',
            items: [
                { title: 'Default', selector: '.btn-group', attributes: {class: 'btn-group'}},
                { title: 'Large', selector: '.btn-group', attributes: {class: 'btn-group btn-group-lg'}},
                { title: 'Small', selector: '.btn-group', attributes: {class: 'btn-group btn-group-sm'}},
                { title: 'Extra small', selector: '.btn-group', attributes: {class: 'btn-group btn-group-xs'}},
                { title: 'Justified', selector: '.btn-group', attributes: {class: 'btn-group btn-group-justified'}},
            ]}];

    DATA.tiny_mce.advanced["content_css"] = bootstrap_css_url;
    DATA.tiny_mce.advanced["table_class_list"] = [
        { title: 'None', value: "" },
        { title: 'Default', value: "table" },
        { title: 'Striped', value: "table table-striped" },
        { title: 'Bordered', value: "table table-bordered" },
        { title: 'Hover rows', value: "table table-hover" },
        { title: 'Condensed', value: "table table-condensed" }
    ];

    DATA.tiny_mce.advanced["table_cell_class_list"] = [
        { title: 'None', value: "" },
        { title: 'Active', value: 'active'},
        { title: 'Success', value: 'success' },
        { title: 'Info', value: 'info' },
        { title: 'Warning', value: 'warning' },
        { title: 'Danger', value: 'danger' },
    ];

    DATA.tiny_mce.advanced["table_row_class_list"] = [
        { title: 'None', value: "" },
        { title: 'Active', value: 'active'},
        { title: 'Success', value: 'success' },
        { title: 'Info', value: 'info' },
        { title: 'Warning', value: 'warning' },
        { title: 'Danger', value: 'danger' },
    ];

    DATA.tiny_mce.advanced["image_class_list"] = [
        { title: 'None', value: "" },
        { title: 'Rounded', value: 'img-rounded'},
        { title: 'Circle', value: 'img-circle' },
        { title: 'Thumbnail', value: 'img-thumbnail' }
    ];

    DATA.tiny_mce.advanced["link_class_list"] = [
        { title: 'None', value: "" },
        { title: 'Default', value: "btn btn-default"},
        { title: 'Primary', value: "btn btn-primary"},
        { title: 'Success', value: "btn btn-success"},
        { title: 'Info', value: "btn btn-info" },
        { title: 'Warning', value: "btn btn-warning" },
        { title: 'Danger', value: "btn btn-danger" },
        { title: 'Disabled', value: "disabled" }
    ];

    // templates
    DATA.tiny_mce.advanced["templates"] = [
        {title: 'Bootstrap panel', description: 'Bootstrap panel', content: "<div class='panel panel-default'> <div class='panel-heading'>Panel heading</div><div class='panel-body'><p>Your content here</p></div></div>"},
        {title: 'Bootstrap panel content + table', description: 'Bootstrap panel with table', content: "<div class='panel panel-default'> <div class='panel-heading'>Panel heading</div><div class='panel-body'><p>Your content here</p></div><table class='table'><thead><tr><th>First Name</th><th>Last Name</th></tr></thead><tbody><tr><td>Owen</td><td>Peredo</td></tr></tbody></table></div>"},
        {title: 'Bootstrap panel only table', description: 'Bootstrap panel with table', content: "<div class='panel panel-default'><div class='panel-heading'>Panel heading</div><table class='table'<thead><tr><th>#</th><th>First Name</th><th>Last Name</th></tr></thead><tbody><tr><th scope='row'>1</th><td>Owen</td><td>Peredo</td></tr></tbody></table></div>"},
        {title: 'Bootstrap panel list', description: 'Bootstrap panel list', content: "<div class='panel panel-default'><div class='panel-heading'>Panel heading</div><div class='panel-body'><p>Your content here</p></div><ul class='list-group'><li class='list-group-item'>Cras justo odio</li><li class='list-group-item'>Dapibus ac facilisis in</li><li class='list-group-item'>Morbi leo risus</li></ul></div>"},
        {title: 'Bootstrap alerts', description: 'Bootstrap alerts', content: "<div class='alert alert-success' role='alert'><strong>Well done!</strong> You successfully read <a href='#' class='alert-link'>this important alert message</a>.</div>"},
        {title: 'Bootstrap breadcrumbs', description: 'Bootstrap breadcrumbs', content: "<ol class='breadcrumb'><li><a href='#'>Home</a></li><li><a href='#'>Library</a></li><li class='active'>Data</li></ol>"},
        {title: 'Bootstrap button groups', description: 'Bootstrap Justified buttons', content: "<div class='btn-group' role='group' aria-label='Justified button group'><a href='#' class='btn btn-default' role='button'>Left</a><a href='#' class='btn btn-default' role='button'>Middle</a><a href='#' class='btn btn-default' role='button'>Right</a><br style='display: none'></div>"},
        {title: 'Bootstrap row 50%', description: 'Bootstrap row 50%', content: "<div class='row'><div class='col-sm-6'><p>50%</p></div><div class='col-sm-6'><p>50%</p></div></div>"},
        {title: 'Bootstrap row 33%', description: 'Bootstrap row 33%', content: "<div class='row'><div class='col-xs-6 col-sm-4'><p>33%</p></div><div class='col-xs-6 col-sm-4'><p>33%</p></div><div class='col-xs-6 col-sm-4'><p>33%</p></div></div>"},
        {title: 'Bootstrap row 25%', description: 'Bootstrap row 25%', content: "<div class='row'><div class='col-xs-6 col-sm-3'><p>25%</p></div><div class='col-xs-6 col-sm-3'><p>25%</p></div><div class='col-xs-6 col-sm-3'><p>25%</p></div><div class='col-xs-6 col-sm-3'><p>25%</p></div></div>"},
        {title: 'Bootstrap row 75-25%', description: 'Bootstrap row 75-25%', content: "<div class='row'><div class='col-sm-9'><p>75%</p></div><div class='col-sm-3'><p>25%</p></div></div>"},
        {title: 'Bootstrap row 25-75%', description: 'Bootstrap row 25-75%', content: "<div class='row'><div class='col-sm-3'><p>25%</p></div><div class='col-sm-9'><p>75%</p></div></div>"},

    ]
});

