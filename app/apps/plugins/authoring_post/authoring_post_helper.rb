module Plugins::AuthoringPost::AuthoringPostHelper
  
  def plugin_authoring_post_the_content(args)
  end

  def plugin_authoring_on_active(plugin)
  end

  def plugin_authoring_on_inactive(plugin)
  end

  def plugin_authoring_post_list(args)
   end

  def plugin_authoring_create_post(args)
  end

  def plugin_authoring_new_post(args)
    args[:extra_settings] << plugin_authoring_form_html(args[:post])
  end

  def plugin_authoring_can_visit(args)
  end

  def plugin_authoring_extra_columns(args)
  end

  def plugin_authoring_filter_post(args)
  end

  private

  def plugin_authoring_form_html(post)
    "
    <div class='form-group'>
      <label class='control-label'>#{t('camaleon_cms.admin.table.author')}</label>
      <select id='post_user_id' #{can?(:edit_other, post.post_type) && (can?(:edit_publish, post.post_type) || !post.published?) ? '' : 'disabled'} name='post[user_id]' class='form-control select valid' aria-invalid='false'>#{plugin_authoring_authors_list(post)}</select>
    </div>
    "
  end

  def plugin_authoring_authors_list(post)
    author_id = post.new_record? ? current_user.id : post.author.id
    ret = ''
    current_site.users.unscoped.where('role <> ?', 'client').order(:username).each do |user|
      ret += "<option value='#{user.id}' #{user.id.eql?(author_id) ? 'selected' : ''}>#{user.username.titleize}#{user.fullname.eql?(user.username.titleize) ? '' : ' (' +  user.fullname + ')' }</option>"
    end
    ret
  end

end
