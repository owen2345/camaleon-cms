module CamaleonCms
  module CommentHelper
    LABELS = { 'approved' => 'success', 'pending' => 'warning', 'spam' => 'danger' }.freeze

    # return common data to save a new comment
    # user_id, author, aothor_email, author_ip, approved, :agent
    def cama_comments_get_common_data
      comment_data = {}
      comment_data[:user_id] = cama_current_user.id
      comment_data[:author] = cama_current_user.the_name
      comment_data[:author_email] = cama_current_user.email
      comment_data[:author_IP] = request.remote_ip.to_s
      comment_data[:approved] = 'approved'
      comment_data[:agent] = request.user_agent.force_encoding('ISO-8859-1').encode('UTF-8')
      comment_data
    end

    # render as html content all comments recursively
    # comments: collection of comments
    def cama_comments_render_html(comments, post_id = nil)
      if post_id.nil? && respond_to?(:controller) && controller.respond_to?(:instance_variable_get)
        post_id = controller.instance_variable_get(:@post)&.id
      end
      comments.decorate.map do |comment|
        author = comment.the_author
        content_tag(:div, class: 'media') do
          [
            content_tag(:div, class: 'media-left') do
              link_to(author.the_admin_profile_url) do
                image_tag(author.the_avatar, class: 'media-object', style: 'width: 64px; height: 64px;')
              end
            end,
            content_tag(:div, class: 'media-body') do
              [
                content_tag(:h4, class: 'media-heading') do
                  [
                    # Escape the author name: User first_name/last_name are no longer sanitized at
                    # save time and this heading is marked html_safe below, so a commenter-controlled
                    # name would otherwise be injected as raw HTML into the moderator's page.
                    ERB::Util.html_escape(author.the_name),
                    ' ',
                    content_tag(:small, comment.the_created_at),
                    ' ',
                    content_tag(:span, t("camaleon_cms.admin.comments.message.#{comment.approved}"),
                                class: "label label-#{LABELS[comment.approved]} pull-right")
                  ].join.html_safe
                end,
                content_tag(:div, sanitize(comment.content), class: 'comment_content'),
                content_tag(:div, class: 'comment_actions') do
                  [
                    content_tag(:div, class: 'pull-left') do
                      [
                        link_to(
                          cama_admin_post_comment_answer_path(post_id, comment.id),
                          data: { comment_id: comment.id },
                          title: t('camaleon_cms.admin.comments.tooltip.reply_comment'),
                          class: 'btn btn-info reply btn-xs ajax_modal'
                        ) { content_tag(:span, '', class: 'fa fa-mail-reply') },
                        ' ',
                        link_to(
                          { action: :destroy, id: comment.id },
                          method: :delete,
                          data: { confirm: t('camaleon_cms.admin.message.delete') },
                          class: 'btn btn-danger btn-xs cama_ajax_request',
                          title: t('camaleon_cms.admin.comments.tooltip.delete_comment')
                        ) { content_tag(:i, '', class: 'fa fa-trash-o') }
                      ].join.html_safe
                    end,
                    content_tag(:div, class: 'pull-right') do
                      [
                        link_to(
                          url_for({ action: :toggle_status, comment_id: comment.id, s: 'a' }),
                          title: t('camaleon_cms.admin.comments.tooltip.approved_comment'),
                          class: "#{comment.approved == 'approved' ? 'hidden' : ''} " \
                                 'btn btn-success approve btn-xs cama_ajax_request'
                        ) { content_tag(:span, '', class: 'fa fa-thumbs-o-up') },
                        ' ',
                        link_to(
                          url_for({ action: :toggle_status, comment_id: comment.id, s: 'p' }),
                          title: t('camaleon_cms.admin.comments.tooltip.comment_pending'),
                          class: "#{comment.approved == 'pending' ? 'hidden' : ''} " \
                                 'btn btn-primary pending btn-xs cama_ajax_request'
                        ) { content_tag(:span, '', class: 'fa fa-warning') },
                        ' ',
                        link_to(
                          url_for({ action: :toggle_status, comment_id: comment.id, s: 's' }),
                          title: t('camaleon_cms.admin.comments.tooltip.comment_spam'),
                          class: "#{comment.approved == 'spam' ? 'hidden' : ''} " \
                                 'btn btn-danger spam btn-xs cama_ajax_request'
                        ) { content_tag(:span, '', class: 'fa fa-bug') }
                      ].join.html_safe
                    end
                  ].join.html_safe
                end,
                content_tag(:hr),
                content_tag(:div, '', class: 'clearfix'),
                cama_comments_render_html(comment.children, post_id)
              ].join.html_safe
            end
          ].join.html_safe
        end
      end.join('').html_safe
    end
  end
end
