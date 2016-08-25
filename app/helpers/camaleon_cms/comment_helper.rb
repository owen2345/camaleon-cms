module CamaleonCms::CommentHelper
  # return common data to save a new comment
  # user_id, author, aothor_email, author_ip, approved, :agent
  def cama_comments_get_common_data
    comment_data = {}
    comment_data[:user_id] = cama_current_user.id
    comment_data[:author] = cama_current_user.the_name
    comment_data[:author_email] = cama_current_user.email
    comment_data[:author_IP] = request.remote_ip.to_s
    comment_data[:approved] = "approved"
    comment_data[:agent] = request.user_agent.force_encoding("ISO-8859-1").encode("UTF-8")
    comment_data
  end

  # render as html content all comments recursively
  # comments: collection of comments
  def cama_comments_render_html(comments)
    res = ""
    labels = {"approved" => "success", "pending"=>"warning", "spam" => "danger" }
    comments.decorate.each do |comment|
      author = comment.the_author
      res << "<div class='media'>
                 <div class='media-left'>
                    <a href='#{author.the_admin_profile_url}'>#{image_tag author.the_avatar, class: 'media-object', style: 'width: 64px; height: 64px;'}</a>
                 </div>
                 <div class='media-body'>
                    <h4 class='media-heading'>#{author.the_name} <small>#{comment.the_created_at}</small> <span class='label label-#{labels[comment.approved]} pull-right'>#{t("camaleon_cms.admin.comments.message.#{comment.approved}")}</span></h4>
                    <div class='comment_content'>#{comment.content}</div>
                    <div class='comment_actions'>
                        <div class='pull-left'>
                            <a href='#{cama_admin_post_comment_answer_path(@post.id, comment.id)}' data-comment-id='#{comment.id}' title='#{t('camaleon_cms.admin.comments.tooltip.reply_comment')}' class='btn btn-info reply btn-xs ajax_modal'><span class='fa fa-mail-reply'></span></a>
                            #{link_to raw('<i class="fa fa-trash-o"></i>'), { action: :destroy, id: comment.id }, method: :delete, data: { confirm: t('camaleon_cms.admin.message.delete') }, class: "btn btn-danger btn-xs cama_ajax_request", title: "#{t('camaleon_cms.admin.comments.tooltip.delete_comment')}" }
                        </div>
                        <div class='pull-right'>
                            <a href='#{url_for({ action: :toggle_status, comment_id: comment.id, s: "a" })}' title='#{t('camaleon_cms.admin.comments.tooltip.approved_comment')}' class='#{"hidden" if comment.approved == "approved"} btn btn-success approve btn-xs cama_ajax_request'><span class='fa fa-thumbs-o-up'></span></a>
                            <a href='#{url_for({ action: :toggle_status, comment_id: comment.id, s: "p" })}' title='#{t('camaleon_cms.admin.comments.tooltip.comment_pending')}' class='#{"hidden" if comment.approved == "pending"} btn btn-primary pending btn-xs cama_ajax_request'><span class='fa fa-warning'></span></a>
                            <a href='#{url_for({ action: :toggle_status, comment_id: comment.id, s: "s" })}' title='#{t('camaleon_cms.admin.comments.tooltip.comment_spam')}' class='#{"hidden" if comment.approved == "spam"} btn btn-danger spam btn-xs cama_ajax_request'><span class='fa fa-bug'></span></a>
                        </div>
                    </div>
                    <hr>
                    <div class='clearfix'></div>
                    #{ cama_comments_render_html comment.children }
                 </div>
              </div>"
    end
    res
  end
end
