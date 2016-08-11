=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  LanguageSelection Post Plugin
  Copyright (C) 2016 by Rafael Costella & Pedro Gryzinsky
  Email: rafael.costella@zrp.com.br & pedro.gryzinsky@zrp.com.br
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
module Plugins::LanguageSelectionPost::LanguageSelectionPostHelper

  def plugin_language_selection_post_the_content(args)
  end

  def plugin_language_selection_on_active(plugin)
    CamaleonCms::Post.all.each do |post|
      post.set_meta("available_languages", I18n.locale.to_s)
    end
  end

  def plugin_language_selection_on_inactive(plugin)
  end

  def plugin_language_selection_create_post(args)
  end

  def plugin_language_selection_new_post(args)
    args[:extra_settings] << plugin_language_selection_form_html(args[:post])
  end

  def plugin_language_selection_can_visit(args)
  end

  def plugin_language_selection_extra_columns(args)
  end

  def plugin_language_selection_filter_post(args)
  end

  private

  def plugin_language_selection_form_html(post)
    append_asset_libraries({"plugin_language_selection_post"=> { js: [plugin_asset_path("js/language_tag.js")] }})

    "
    <script>window.language_selection_post_locales = #{current_site.get_languages.map(&:to_s)}</script>

    <div class='form-group'>
      <label class='control-label'>#{t('camaleon_cms.admin.sidebar.languages')}</label>
      <input name='meta[available_languages]' class='languageinput' value='#{post.available_languages}' />
    </div>
    "
  end
end
