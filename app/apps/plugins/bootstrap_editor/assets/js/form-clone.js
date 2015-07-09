jQuery(function($){
    DATA.tiny_mce.advanced["style_formats_merge"] = true;
    DATA.tiny_mce.advanced["style_formats"] = [
        /*{
            title: 'Bootstrap Table',
            items: [
                { title: 'Default', selector: 'table', attibutes: {class: "mce-item-table table"} },
                { title: 'Striped', selector: 'table', attibutes: {class: "mce-item-table table table-striped"} },
                { title: 'Bordered', selector: 'table', attibutes: {class: "mce-item-table table table-bordered"} },
                { title: 'Hover rows', selector: 'table', attibutes: {class: "mce-item-table table table-hover"} },
                { title: 'Condensed', selector: 'table', attibutes: {class: "mce-item-table table table-condensed"} }
            ]},
        {
            title: 'Bootstrap Table rows',
            items: [
                { title: 'Active', selector: 'tr', attibutes: {class: 'active'} },
                { title: 'Success', selector: 'tr', attibutes: {class: 'success'} },
                { title: 'Info', selector: 'tr', attibutes: {class: 'info'} },
                { title: 'Warning', selector: 'tr', attibutes: {class: 'warning'} },
                { title: 'Danger', selector: 'tr', attibutes: {class: 'danger'} },
            ]},
        {
            title: 'Bootstrap Table Cells',
            items: [
                { title: 'Active', selector: 'td', attibutes: {class: 'active'} },
                { title: 'Success', selector: 'td', attibutes: {class: 'success'} },
                { title: 'Info', selector: 'td', attibutes: {class: 'info'} },
                { title: 'Warning', selector: 'td', attibutes: {class: 'warning'} },
                { title: 'Danger', selector: 'td', attibutes: {class: 'danger'} },
            ]},*/

        // buttons
        {
            title: 'Bootstrap Buttons Size',
            items: [
                { title: 'Large', selector: '.btn', classes: "btn-lg" },
                { title: 'Small', selector: '.btn', classes: "btn-sm" },
                { title: 'Extra Small', selector: '.btn', classes: "btn-xs" },
                { title: 'Block', selector: '.btn', classes: "btn-block" },
                { title: 'Disabled', selector: '.btn', classes: "disabled" }
            ]},

        // panels
        {
            title: 'Bootstrap Panels',
            items: [
                { title: 'Primary', selector: '.panel', classes: "panel-primary" },
                { title: 'Success', selector: '.panel', classes: "panel-success" },
                { title: 'Info', selector: '.panel', classes: "panel-info" },
                { title: 'Warning', selector: '.panel', classes: "panel-warning" },
                { title: 'Danger', selector: '.panel', classes: "panel-danger" }
            ]},

        // responsive
        {
            title: 'Responsive media',
            items: [
                { title: 'Primary', block: "div", selector: '.mce-object', classes: "embed-responsive-item" }
            ]},

        {
            title: "asdasdasda",
            items: [
                { title: 'sssssNormal Line Height', inline: 'span', styles: { "line-height": '200%' } }
            ]
        }];

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
    DATA.tiny_mce.advanced["plugins"] = DATA.tiny_mce.advanced["plugins"]+",template";
    //DATA.tiny_mce.advanced["toolbar3"] = "table | hr removeformat | subscript superscript | charmap emoticons | print fullscreen | ltr rtl | spellchecker | visualchars visualblocks nonbreaking template pagebreak restoredraft";
    DATA.tiny_mce.advanced["templates"] = [
        {title: 'Bootstrap panel', description: 'Bootstrap panel', content: "<div class='panel panel-default'> <div class='panel-heading'>Panel heading</div><div class='panel-body'><p>Your content here</p></div></div>"},
        {title: 'Bootstrap panel content + table', description: 'Bootstrap panel with table', content: "<div class='panel panel-default'> <div class='panel-heading'>Panel heading</div><div class='panel-body'><p>Your content here</p></div><table class='table'><thead><tr><th>First Name</th><th>Last Name</th></tr></thead><tbody><tr><td>Owen</td><td>Peredo</td></tr></tbody></table></div>"},
        {title: 'Bootstrap panel only table', description: 'Bootstrap panel with table', content: "<div class='panel panel-default'><div class='panel-heading'>Panel heading</div><table class='table'<thead><tr><th>#</th><th>First Name</th><th>Last Name</th></tr></thead><tbody><tr><th scope='row'>1</th><td>Owen</td><td>Peredo</td></tr></tbody></table></div>"},
        {title: 'Bootstrap panel list', description: 'Bootstrap panel list', content: "<div class='panel panel-default'><div class='panel-heading'>Panel heading</div><div class='panel-body'><p>Your content here</p></div><ul class='list-group'><li class='list-group-item'>Cras justo odio</li><li class='list-group-item'>Dapibus ac facilisis in</li><li class='list-group-item'>Morbi leo risus</li></ul></div>"}
    ]
});