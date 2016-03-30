=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  Authoring Post Plugin
  Copyright (C) 2016 by Second Bureau
  Email: gilles@secondbureau.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
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