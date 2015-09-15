=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
module FrontendConcern extend ActiveSupport::Concern
  # visiting sitemap.xml
  def sitemap
    path = Rails.root.join("public", "sitemaps", current_site.slug, "sitemap.xml")
    if File.exists?(path)
      respond_to do |format|
        format.html do
          @xml = File.read(path)
          render "sitemap"
        end
        format.xml { render(xml: open(path).read) }
      end
    else
      Thread.abort_on_exception=true
      Thread.new do
        %x(rake camaleon_cms:sitemap)
        ActiveRecord::Base.connection.close
      end
      render text: "Sitemap not found. Generating... Please wait and refresh later.", status: :not_found
    end
  end

  # accessing for robots.txt
  def robots
  end

  # save comment from a post
  def save_comment
    @post = current_site.posts.find_by_id(params[:post_id]).decorate
    if @post.can_commented?
      comment_data = {}
      comment_data[:user_id] = current_user.id
      comment_data[:author] = current_user.the_name
      comment_data[:author_email] = current_user.email
      comment_data[:author_url] = ""
      comment_data[:author_IP] = request.remote_ip.to_s
      comment_data[:approved] = current_site.front_comment_status
      comment_data[:agent] = request.user_agent.force_encoding("ISO-8859-1").encode("UTF-8")
      comment_data[:content] = params[:post_comment][:content]
      @comment = @post.comments.main.new(comment_data)
      if @comment.save
        flash[:notice] = t('admin.comments.message.created')
        redirect_to :back
      else
        flash[:error] = t('admin.validate.required')
        redirect_to :back
      end
    else
      flash[:error] = t('admin.message.unauthorized')
      redirect_to :back
    end
  end
end
