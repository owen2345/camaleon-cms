module CamaleonCms
  module Admin
    module ApplicationHelper
      # include CamaleonCms::Admin::ApiHelper
      include CamaleonCms::Admin::MenusHelper
      include CamaleonCms::Admin::PostTypeHelper
      include CamaleonCms::Admin::CategoryHelper
      include CamaleonCms::Admin::CustomFieldsHelper

      # render pagination for current items
      # items is a will pagination object
      # sample: <%= cama_do_pagination(@posts) %>
      def cama_do_pagination(items, *will_paginate_options)
        will_paginate_options = will_paginate_options.extract_options!
        custom_class = will_paginate_options.delete(:panel_class)
        content_tag(:div, class: "row #{custom_class} pagination_panel cama_ajax_request") do
          concat(content_tag(:div, class: 'col-md-10') do
            will_paginate(items, will_paginate_options)
          rescue StandardError
            ''
          end)
          concat(content_tag(:div, class: 'col-md-2 text-right total-items') do
            content_tag(:strong) do
              total = begin
                items.total_entries
              rescue StandardError
                items.count
              end
              "#{I18n.t('camaleon_cms.admin.table.total', default: 'Total')}: #{total}"
            end
          end)
        end
      end

      # print code with auto copy
      def cama_shortcode_print(code)
        content_tag(
          :input, nil, class: 'code_style', readonly: true, onmousedown: 'this.clicked = 1;',
                       onfocus: 'if (!this.clicked) this.select(); else this.clicked = 2;',
                       onclick: 'if (this.clicked == 2) this.select(); this.clicked = 0;', tabindex: '-1', value: code
        )
      end
    end
  end
end
