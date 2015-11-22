=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
module CamaleonCms::FrontendConcern extend ActiveSupport::Concern
  # visiting sitemap.xml
  # With hook "on_render_sitemap" you can skip post_types, categories, tags or posts
  #   you can change render file and layout
  #   you can add custom sitemap elements in the attr "custom", like: https://github.com/owen2345/camaleon-cms/issues/106#issuecomment-146232211
  #   you can customize your content for html or xml format
  def sitemap
    r = {layout: (params[:format] == "html" ? (self.send :_layout) : false), render: "sitemap", custom: {}, format: params[:format], skip_post_ids: [], skip_posttype_ids: [], skip_cat_ids: [], skip_tag_ids: []}
    hooks_run("on_render_sitemap", r)
    @r = r
    render r[:render], layout: r[:layout]
  end

  # accessing for robots.txt
  def robots
    r = {layout: false, render: "robots"}
    hooks_run("on_render_robots", r)
    render r[:render], layout: r[:layout]
  end

  # rss for current site
  def rss
    r = {layout: false, render: "rss"}
    hooks_run("on_render_rss", r)
    render r[:render], layout: r[:layout]
  end

  # save comment from a post
  def save_comment
    @post = current_site.posts.find_by_id(params[:post_id]).decorate
    if @post.can_commented?
      comment_data = {}
      comment_data[:user_id] = cama_current_user.id
      comment_data[:author] = cama_current_user.the_name
      comment_data[:author_email] = cama_current_user.email
      comment_data[:author_url] = ""
      comment_data[:author_IP] = request.remote_ip.to_s
      comment_data[:approved] = current_site.front_comment_status
      comment_data[:agent] = request.user_agent.force_encoding("ISO-8859-1").encode("UTF-8")
      comment_data[:content] = params[:post_comment][:content]
      @comment = @post.comments.main.new(comment_data)
      if @comment.save
        flash[:notice] = t('camaleon_cms.admin.comments.message.created')
        redirect_to :back
      else
        flash[:error] = t('camaleon_cms.admin.validate.required')
        redirect_to :back
      end
    else
      flash[:error] = t('camaleon_cms.admin.message.unauthorized')
      redirect_to :back
    end
  end
end
