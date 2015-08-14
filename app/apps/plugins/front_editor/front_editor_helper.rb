=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
module Plugins::FrontEditor::FrontEditorHelper
  def front_editor_post_the_thumb(args)
    # args[:image] += " &rarr; " + link_to("Edit", args[:post].decorate.the_edit_url, target: "_blank", style: "margin-top: -4px;")
  end

  def front_editor_post_the_content(args)
    if front_editor_can_edit?
      args[:content] += front_editor_link(args[:post].decorate.the_edit_url)
    end
  end

  def front_editor_post_the_title(args)
    # if front_editor_can_edit?
    #   args[:title] += front_editor_link(args[:post].decorate.the_edit_url)
    #   args[:title] = args[:title].html_safe
    # end
  end

  def front_editor_post_the_excerpt(args)
    # args[:content] += " &rarr; " + link_to(t("plugins.front_editor.edit"), args[:post].decorate.the_edit_url, target: "_blank") unless params[:controller].start_with?("admin/")
  end

  def front_editor_sidebar_render(args)

  end

  def front_editor_taxonomy_the_title(args)
    # if front_editor_can_edit?
    #   args[:title] += front_editor_link(args[:object].decorate.the_edit_url)
    #   args[:title] += front_editor_link(admin_post_type_posts_url(args[:object].id), t("plugins.front_editor.contents")) if args[:object].class.name == "PostType"
    #   args[:title] = args[:title].html_safe
    # end
  end

  def front_editor_taxonomy_the_content(args)
    # args[:content] += " &rarr; " + link_to(t("plugins.front_editor.edit"), args[:object].decorate.the_edit_url, target: "_blank") unless params[:controller].start_with?("admin/")
  end

  def front_editor_taxonomy_the_excerpt(args)
    # args[:content] += " &rarr; " + link_to(t("plugins.front_editor.edit"), args[:object].decorate.the_edit_url, target: "_blank") unless (params[:controller].start_with?("admin/") || args[:object].class.name == "Site")
  end

  # build the edit url
  # title: title for the link
  def front_editor_link(url, title = nil)
    @_front_editor_counter ||= 0
    @_front_editor_counter += 1
    return "<span style='font-size:11px !important;cursor:pointer;' data-url='#{url}' data-id='' onclick='return front_editor_do(this, #{@_front_editor_counter})'> &rarr; #{title || t("plugins.front_editor.edit")}</span>" if front_editor_can_edit?
    ""
  end

  def front_editor_front_before
    append_asset_content("<script>function front_editor_do(thiss, num){ window.open(thiss.getAttribute('data-url'), 'Window '+num);return false;}</script>")
  end

  private
  def front_editor_can_edit?
    signin? && current_user.admin? && current_site.plugin_installed?("front_editor") && !request.env['PATH_INFO'].start_with?("/admin")
  end

end
