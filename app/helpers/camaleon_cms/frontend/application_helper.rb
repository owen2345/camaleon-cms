=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
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
    if request.present?
      if options.include?(:locale) && options[:locale] == false
        options.delete(:locale)
      else
        options[:locale] = I18n.locale if !options[:locale].present? && current_site.get_languages.size > 1
      end
      options[:locale] = nil if options[:locale].present? && current_site.get_languages.first.to_s == options[:locale].to_s
    end
    options.delete(:format) if PluginRoutes.system_info["skip_format_url"].present?
    send(url_to.gsub('-', '_'), *(args << options))
  end
end
