module CamaleonCms::FrontendConcern extend ActiveSupport::Concern
  # visiting sitemap.xml
  # With hook "on_render_sitemap" you can skip post_types, categories, tags or posts
  #   you can change render file and layout
  #   you can add custom sitemap elements in the attr "custom", like: https://github.com/owen2345/camaleon-cms/issues/106#issuecomment-146232211
  #   you can customize your content for html or xml format
  def sitemap
    r = {layout: (params[:format] == "html" ? nil : false), render: "sitemap", custom: {}, format: params[:format], skip_post_ids: [], skip_posttype_ids: [], skip_cat_ids: [], skip_tag_ids: []}
    hooks_run("on_render_sitemap", r)
    @r = r
    render r[:render], (!r[:layout].nil? ? {layout: r[:layout]} : {})
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
    render r[:render], layout: r[:layout], formats: [:rss]
  end

  # save comment from a post
  def save_comment
    flash[:comment_submit] = {}
    @post = current_site.posts.find_by_id(params[:post_id]).decorate
    user = cama_current_user
    comment_data = {}
    if !user.present? && current_site.get_option('permit_anonimos_comment', false)
      user = current_site.get_anonymous_user
      comment_data[:is_anonymous] = true
      comment_data[:author] = params[:post_comment][:name]
      comment_data[:author_email] = params[:post_comment][:email]
    else
      comment_data[:author] = user.fullname
      comment_data[:author_email] = user.email
    end

    if @post.can_commented? && user.present?
      comment_data[:user_id] = user.id
      comment_data[:author_url] = params[:post_comment][:url] || ""
      comment_data[:author_IP] = request.remote_ip.to_s
      comment_data[:approved] = current_site.front_comment_status
      comment_data[:agent] = request.user_agent.force_encoding("ISO-8859-1").encode("UTF-8")
      comment_data[:content] = params[:post_comment][:content]
      @comment = params[:post_comment][:parent_id].present? ? @post.comments.find_by_id(params[:post_comment][:parent_id]).children.new(comment_data) :  @post.comments.main.new(comment_data)
      if @comment.save
        flash[:comment_submit][:notice] = t('camaleon_cms.admin.comments.message.created')
      else
        flash[:comment_submit][:error] = "#{t('camaleon_cms.common.comment_error', default: 'An error was occurred on save comment')}:<br> #{@comment.errors.full_messages.join(', ')}"
      end
    else
      flash[:comment_submit][:error] = t('camaleon_cms.admin.message.unauthorized')
    end
    params[:format] == 'json' ? render(json: flash.discard(:comment_submit).to_hash) : redirect_to(:back)
  end
end
