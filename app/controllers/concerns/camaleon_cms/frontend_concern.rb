module CamaleonCms
  module FrontendConcern
    extend ActiveSupport::Concern
    # visiting sitemap.xml
    # With hook "on_render_sitemap" you can skip post_types, categories, tags or posts
    #   you can change render file and layout
    #   you can add custom sitemap elements in the attr "custom",
    #     like: https://github.com/owen2345/camaleon-cms/issues/106#issuecomment-146232211
    #   you can customize your content for html or xml format
    def sitemap
      r = { layout: (params[:format] == 'html' ? nil : false), render: 'sitemap', custom: {}, format: params[:format],
            skip_post_ids: [], skip_posttype_ids: [], skip_cat_ids: [], skip_tag_ids: [] }
      hooks_run('on_render_sitemap', r)
      @r = r
      render r[:render], (!r[:layout].nil? ? { layout: r[:layout] } : {})
    end

    # accessing for robots.txt
    def robots
      r = { layout: false, render: 'robots' }
      hooks_run('on_render_robots', r)
      render r[:render], layout: r[:layout]
    end

    # rss for current site
    def rss
      r = { layout: false, render: 'rss' }
      hooks_run('on_render_rss', r)
      render r[:render], layout: r[:layout], formats: [:rss]
    end

    # save comment from a post
    def save_comment
      flash[:comment_submit] = {}
      # Security (audit Low): this is a public endpoint. A post id naming no post used to reach
      # `.decorate` on nil (500), and the anonymous branch indexed a missing post_comment param.
      # Fail closed with a graceful error instead of a 500 an attacker can trigger at will.
      @post = current_site.posts.find_by(id: params[:post_id])&.decorate
      user = cama_current_user
      comment_data = {}
      if @post.nil?
        flash[:comment_submit][:error] = t('.post_not_found', default: 'Post not found')
      elsif !@post.can_commented?
        flash[:comment_submit][:error] = t('.comments_not_enabled', default: 'This post can not be commented')
      end

      post_comment = params[:post_comment] || {}

      if user.present?
        comment_data[:author] = user.fullname
        comment_data[:author_email] = user.email
      elsif current_site.get_option('permit_anonimos_comment', false)
        user = current_site.get_anonymous_user
        comment_data[:is_anonymous] = true
        comment_data[:author] = post_comment[:name]
        comment_data[:author_email] = post_comment[:email]
        if current_site.is_enable_captcha_for_comments? && !cama_captcha_verified?
          flash[:comment_submit][:error] =
            t('camaleon_cms.admin.users.message.error_captcha',
              default: 'Invalid captcha value')
        end
      end

      unless flash[:comment_submit][:error]
        if user.present?
          comment_data[:user_id] = user.id
          comment_data[:author_url] = post_comment[:url] || ''
          comment_data[:author_IP] = request.remote_ip.to_s
          comment_data[:approved] = current_site.front_comment_status
          # Browsers always send a User-Agent but API clients/bots may not; record it nil-safely
          # and without mutating the request's header string in place.
          comment_data[:agent] = request.user_agent.to_s.encode('UTF-8', 'ISO-8859-1')
          comment_data[:content] = post_comment[:content]
          # Security (audit Low): a crafted parent_id naming no comment on this post made find_by
          # return nil and the chained `.children` raise (500). Resolve the parent first and fail
          # closed with a graceful error when a supplied parent_id matches nothing.
          parent_id = post_comment[:parent_id]
          parent = @post.comments.find_by(id: parent_id) if parent_id.present?
          if parent_id.present? && parent.nil?
            flash[:comment_submit][:error] = t('.parent_comment_not_found', default: 'Parent comment not found')
          else
            @comment = parent ? parent.children.new(comment_data) : @post.comments.main.new(comment_data)
            if @comment.save
              flash[:comment_submit][:notice] = t('camaleon_cms.admin.comments.message.created')
            else
              base = t('camaleon_cms.common.comment_error', default: 'An error was occurred on save comment')
              flash[:comment_submit][:error] = "#{base}:<br> #{@comment.errors.full_messages.join(', ')}"
            end
          end
        else
          flash[:comment_submit][:error] = t('camaleon_cms.admin.message.unauthorized')
        end
      end

      return render(json: flash.discard(:comment_submit).to_hash) if params[:format] == 'json'

      redirect_to(request.referer || @post&.the_url(as_path: true) || '/')
    end
  end
end
