module Admin::ApplicationHelper
  # include Admin::ApiHelper
  include Admin::MenusHelper
  include Admin::PostTypeHelper
  include Admin::CategoryHelper

  # load system notification
  def admin_system_notifications(args)
    if Date.parse(current_site.get_option("date_notified", 2.days.ago).to_s) < Date.today || true
      current_site.set_option("date_notified", Date.today)
      url = "http://camaleon.tuzitio.com/plugins/camaleon_notification/?version=#{PluginRoutes.system_info[:version] rescue "1.0"}&admin_locale=#{current_site.get_admin_language}&site=#{current_site.the_url}"
      Thread.new do
        current_site.set_meta("date_notified_message", open(url).read)
        ActiveRecord::Base.connection.close #closing connection
      end
    end
    args[:content] << current_site.get_meta("date_notified_message", "")
  end
end