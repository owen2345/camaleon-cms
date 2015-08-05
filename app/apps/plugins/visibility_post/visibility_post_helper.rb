=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
module Plugins::VisibilityPost::VisibilityPostHelper
  def plugin_visibility_post_the_content(args) #{content: object.content.translate(@_deco_locale), post: object}
    if args[:post].visibility == "password"
      return if params[:post_password].present? && params[:post_password] == args[:post].visibility_value
      args[:content] = _password_form
    end
  end

  def plugin_visibility_on_active(plugin)
    # results = ActiveRecord::Base.connection.execute("ALTER TABLE posts ADD visibility varchar(100) default 'public'")
    # results = ActiveRecord::Base.connection.execute("ALTER TABLE posts ADD visibility_value text")
  end

  def plugin_visibility_on_inactive(plugin)
    # results = ActiveRecord::Base.connection.execute("ALTER TABLE posts drop column visibility")
    # results = ActiveRecord::Base.connection.execute("ALTER TABLE posts drop column visibility_value")
  end

  def plugin_visibility_post_list(args)
    args[:posts] = args[:posts].where(visibility: "private") if params[:s] == "private"
    args[:btns][:private] = "#{t('admin.table.private')} (#{args[:all_posts].where(visibility: "private").size})"
  end

  def plugin_visibility_create_post(args)
    save_visibility(args[:post])
  end

  def plugin_visibility_new_post(args)
    args[:extra_settings] << form_html(args[:post])
  end

  def plugin_visibility_can_visit(args)
    post = args[:post]
    return args[:flag] = false if post.published_at.present? && post.published_at > Time.now
    return if post.visibility != 'private'
    args[:flag] = false unless signin? && post.visibility_value.split(",").include?(current_user.get_role(current_site).id)
  end

  def plugin_visibility_extra_columns(args)
    if args[:from_body]
      args[:content] = "<td><i class='fa fa-#{{"private"=>"lock", ""=>"lock", "public"=>"eye", "password"=>"eye-slash"}[args[:post].visibility]}'></i> #{args[:post].visibility}</td>"
      args[:content] = "<td>#{args[:post].the_created_at if args[:post].published_at.present?}</td>"
    else
      args[:content] = "<th>#{t('admin.table.visibility')}</th>"
      args[:content] = "<th>#{t('admin.table.date_published')}</th>"
    end
  end

  def plugin_visibility_filter_post(args)
    args[:active_record] = args[:active_record].where("(posts.published_at is null or posts.published_at <= ?)", Time.now)
    if signin?
      args[:active_record] = args[:active_record].where("visibility != 'private' or (visibility = 'private' and FIND_IN_SET(?, posts.visibility_value))", current_site.visitor_role)
    else
      args[:active_record] = args[:active_record].where("visibility != 'private'")
    end
  end

  private
  def _password_form()

    "<form class='col-md-4'>
        <h4>Protected article</h4>
        <div class='control-group'>
          <label class='control-label'>#{t('admin.post_type.enter_password')}:</label>
          <input type='text' name='post_password' value='' class='form-control' />
        </div>
    <form>"
  end

  def save_visibility(post)
    if post.visibility == "private"
      post.visibility_value = params[:post_private_groups].join(",")
      post.save!
    end
  end

  def form_html(post)
    append_asset_libraries({"plugin_visibility"=> { js: [plugin_asset_path("visibility_post", "js/form.js")] }})
    add_asset_library('datepicker')

    "
    <div class='form-group'>
                  <label class='control-label'>#{t('admin.post_type.published_date')}</label>
                  <div id='datetimepicker' data-locale='#{current_locale}' class='input-append date'>
                      <input type='text' name='post[published_at]' data-format='yyyy-MM-dd hh:mm:ss'  value='#{@post[:published_at]}' />
                      <span class='add-on input-group-addon'><span class='glyphicon glyphicon-calendar'></span></span>
                  </div>
    </div><!-- calendar for published at -->

    <div id='panel-post-visibility' class='form-group'>

      <label class='control-label'>#{t('admin.table.visibility')}: <span class='visibility_label'></span></label> -

      <a class='edit-visibility' href='#'><span aria-hidden='true'>#{t('admin.button.edit')}</span></a>

      <div class='panel-options hidden'>

        <label style='display: block;'><input type='radio' name='post[visibility]' claass='radio' value='public' #{"checked=''" if !post.visibility.present? || "public" == post.visibility}> #{t('admin.table.public')}</label>
        <div></div>

        <label style='display: block;'><input type='radio' name='post[visibility]' claass='radio' value='private' #{"checked=''" if "private" == post.visibility}> #{t('admin.table.private')}</label>
        <div style='padding-left: 20px;'>#{groups_list(post)}</div>

        <label style='display: block;'><input type='radio' name='post[visibility]' claass='radio' value='password' #{"checked=''" if "password" == post.visibility}> #{t('admin.table.password_protection')}</label>
        <div><input type='text' class='form-control' name='post[visibility_value]' value='#{post.visibility_value if "password" == post.visibility}'></div>

        <p>
          <a class='lnk_hide' href='#'>#{t('admin.table.hide')}</a>
        </p>
      </div>
    </div>"
  end

  def groups_list(post)
    res = []
    current_groups = []
    current_groups = post.visibility_value.split(",") if post.visibility == "private"
    current_site.user_roles.each do |role|
      res << "<label><input type='checkbox' name='post_private_groups[]' class='' value='#{role.slug}' #{"checked=''" if current_groups.include?(role.slug.to_s) }> #{role.name}</label><br>"
    end
    res.join("")
  end

end