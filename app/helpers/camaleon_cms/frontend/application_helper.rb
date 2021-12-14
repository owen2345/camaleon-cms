module CamaleonCms::Frontend::ApplicationHelper
  include CamaleonCms::Frontend::SiteHelper
  include CamaleonCms::Frontend::NavMenuHelper
  include CamaleonCms::Frontend::SeoHelper
  include CamaleonCms::Frontend::ContentSelectHelper

  # add where conditionals to filter private/hidden/expired/drafts/unpublished
  # note: only for post records
  def verify_front_visibility(active_record)
    active_record = active_record.visible_frontend
    r = {active_record: active_record}
    hooks_run("filter_post", r)
    r[:active_record]
  end

  # fix for url_to or url_path or any other who need add automatically current locale in the url
  # sample: cama_url_to_fixed("root_url", data: "asdasd", y: 12)
  # => http://localhost/fr?data=asdasd&y=12
  # note: if current locale is the default language, then locale is not added in the url
  def cama_url_to_fixed(url_to, *args)
    options = args.extract_options!
    _current_site = options.delete(:site) || current_site
    if request.present?
      if options.include?(:locale) && options[:locale] == false
        options.delete(:locale)
      else
        options[:locale] = I18n.locale if !options[:locale].present? && _current_site && _current_site.get_languages.size > 1
      end
      options[:locale] = nil if options[:locale].present? && _current_site && _current_site.get_languages.first.to_s == options[:locale].to_s
    end

    options.delete(:format) if PluginRoutes.system_info["skip_format_url"].present?
    cama_current_site_host_port(options) unless options.keys.include?(:host)
    send(url_to.gsub('-', '_'), *(args << options))
  end
end
