module CamaleonCms::Admin::ApplicationHelper
  # include CamaleonCms::Admin::ApiHelper
  include CamaleonCms::Admin::MenusHelper
  include CamaleonCms::Admin::PostTypeHelper
  include CamaleonCms::Admin::CategoryHelper
  include CamaleonCms::Admin::CustomFieldsHelper

  # load system notification
  def admin_system_notifications(args)
    if Date.parse(current_site.get_option("date_notified", 2.days.ago).to_s) < Date.today
      current_site.set_option("date_notified", Date.today)
      url = "http://camaleon.tuzitio.com/plugins/camaleon_notification/?version=#{CamaleonCms::VERSION}&admin_locale=#{current_site.get_admin_language}&site=#{current_site.the_url}"
      Thread.new do
        current_site.set_meta("date_notified_message", open(url).read)
        ActiveRecord::Base.connection.close #closing connection
      end
    end
    args[:content] << current_site.get_meta("date_notified_message", "")
  end

  # render pagination for current items
  # items is a will pagination object
  # sample: <%= raw cama_do_pagination(@posts) %>
  def cama_do_pagination(items, *will_paginate_options)
    will_paginate_options = will_paginate_options.extract_options!
    custom_class = will_paginate_options[:panel_class]
    will_paginate_options.delete(:panel_class)
    "<div class='row #{custom_class} pagination_panel cama_ajax_request'>
        <div class='col-md-6'>
          #{will_paginate(items, will_paginate_options) rescue '' }
        </div>
        <div class='col-md-6 text-right total-items'>
          <strong>Total: #{items.total_entries rescue items.count} </strong>
        </div>
    </div>"
  end

  # return the locale for frontend translations initialized in admin controller
  # used by models like posts, categories, ..., sample: my_post.the_url
  # fix for https://github.com/owen2345/camaleon-cms/issues/233#issuecomment-215385432
  def cama_get_i18n_frontend
    @cama_i18n_frontend
  end

  # print code with auto copy
  def cama_shortcode_print(code)
    "<input onmousedown=\"this.clicked = 1;\" readonly onfocus=\"if (!this.clicked) this.select(); else this.clicked = 2;\" onclick=\"if (this.clicked == 2) this.select(); this.clicked = 0;\" class='code_style' tabindex='-1' value=\"#{code}\">"
  end
end
