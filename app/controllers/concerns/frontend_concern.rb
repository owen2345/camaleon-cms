module FrontendConcern extend ActiveSupport::Concern
  def sitemap
    path = Rails.root.join("public", "sitemaps", current_site.slug, "sitemap.xml")
    respond_to do |format|
      format.html { render "sitemap" }
      format.xml { (File.exists?(path) ? render(xml: open(path).read) : render(text: "Sitemap not found.", status: :not_found)) }
    end
  end


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