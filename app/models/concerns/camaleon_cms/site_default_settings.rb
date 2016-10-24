module CamaleonCms::SiteDefaultSettings extend ActiveSupport::Concern
# default structure for each new site
  def default_settings
    default_post_type = [
        {name: 'Post', description: 'Posts', options: {has_category: true, has_tags: true, not_deleted: true, has_summary: true, has_content: true, has_comments: true, has_picture: true, has_template: true, }},
        {name: 'Page', description: 'Pages', options: {has_category: false, has_tags: false, not_deleted: true, has_summary: false, has_content: true, has_comments: false, has_picture: true, has_template: true, has_layout: true}}
    ]
    default_post_type.each do |pt|
      model_pt = self.post_types.create({name: pt[:name], slug: pt[:name].to_s.parameterize, description: pt[:description], data_options: pt[:options]})
    end

    # nav menus
    @nav_menu = self.nav_menus.new({name: "Main Menu", slug: "main_menu"})
    if @nav_menu.save
      self.post_types.all.each do |pt|
        if pt.slug == "post"
          title = "Sample Post"
          slug = 'sample-post'
          content = "<p>Lorem ipsum dolor sit amet, consectetur adipiscing elit. Integer pharetra ut augue in posuere. Nulla non malesuada dui. Sed egestas tortor ut purus tempor sodales. Duis non sollicitudin nulla, quis mollis neque. Integer sit amet augue ac neque varius auctor. Vestibulum malesuada leo leo, at semper libero efficitur nec. Etiam semper nisi ac nisi ullamcorper, sed tincidunt purus elementum. Mauris ac congue nibh. Quisque pretium eget leo nec suscipit. </p> <p> Vestibulum ultrices orci ut congue interdum. Morbi dolor nunc, imperdiet vel risus semper, tempor dapibus urna. Phasellus luctus pharetra enim quis volutpat. Integer tristique urna nec malesuada ullamcorper. Curabitur dictum, lectus id ultrices rhoncus, ante neque auctor erat, ut sodales nisi odio sit amet lorem. In hac habitasse platea dictumst. Quisque orci orci, hendrerit at luctus tristique, lobortis in diam. Curabitur ligula enim, rhoncus ut vestibulum a, consequat sit amet nisi. Aliquam bibendum fringilla ultrices. Aliquam erat volutpat. Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia Curae; In justo mi, congue in rhoncus lobortis, facilisis in est. Nam et rhoncus purus. </p> <p> Sed sagittis auctor lectus at rutrum. Morbi ultricies felis mi, ut scelerisque augue facilisis eu. In molestie quam ex. Quisque ut sapien sed odio tempus imperdiet. In id accumsan massa. Morbi quis nunc ullamcorper, interdum enim eu, finibus purus. Vestibulum ac fermentum augue, at tempus ante. Aliquam ultrices, purus ut porttitor gravida, dui augue dignissim massa, ac tempor ante dolor at arcu. Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas. Suspendisse placerat risus est, eget varius mi ultricies in. Duis non odio ut felis dapibus eleifend. In fringilla enim lobortis placerat efficitur. </p> <p> Nulla sodales faucibus urna, quis viverra dolor facilisis sollicitudin. Aenean ac egestas nibh. Nam non tortor eget nibh scelerisque fermentum. Etiam ornare, nunc ut luctus mollis, ante dolor consectetur augue, non scelerisque odio est a nulla. Nullam cursus egestas nulla, nec commodo nibh suscipit ut. Mauris ut felis sem. Aenean at mi at nisi dictum blandit sit amet at erat. Etiam eget lobortis tellus. Curabitur in commodo arcu, at vehicula tortor. </p>"
        else
          title = "Welcome"
          slug = 'welcome'
          content = "<p style='text-align: center;'><img width='155' height='155' src='http://camaleon.tuzitio.com/media/132/logo2.png' alt='logo' /></p><p><strong>Camaleon CMS</strong>&nbsp;is a free and open-source tool and a fexible content management system (CMS) based on <a href='http://rubyonrails.org'>Ruby on Rails 4</a>&nbsp;and MySQL.&nbsp;</p> <p>With Camaleon you can do the following:</p> <ul> <li>Create instantly a lot of sites&nbsp;in the same installation</li> <li>Manage your content information in several languages</li> <li>Extend current functionality by&nbsp;plugins (MVC structure and no more echo or prints anywhere)</li> <li>Create or install different themes for each site</li> <li>Create your own structure without coding anything (adapt Camaleon as you want&nbsp;and not you for Camaleon)</li> <li>Create your store and start to sell your products using our plugins</li> <li>Avoid web attacks</li> <li>Compare the speed and enjoy the speed of your new Camaleon site</li> <li>Customize or create your themes for mobile support</li> <li>Support&nbsp;more visitors at the same time</li> <li>Manage your information with a panel like wordpress&nbsp;</li> <li>All urls are oriented for SEO</li> <li>Multiples roles of users</li> </ul>"
        end
        user = self.users.admin_scope.first
        user = self.users.admin_scope.create({email: 'admin@local.com', username: 'admin', password: 'admin123', password_confirmation: 'admin123', first_name: 'Administrator'}) unless user.present?
        post = pt.add_post({title: title, slug: slug, content: content, user_id: user.id, status: 'published'})
        @nav_menu.append_menu_item({label: title, type: 'post', link: post.id})
      end
    end
    get_anonymous_user
  end

  # auto create default user roles
  def set_default_user_roles(post_type = nil)
    user_role = self.user_roles.where({slug: 'admin', term_group: -1}).first_or_create({name: 'Administrator', description: 'Default roles admin'})
    if user_role.valid?
      d, m = {}, {}
      pts = self.post_types.all.pluck(:id)
      CamaleonCms::UserRole::ROLES[:post_type].each { |value| d[value[:key]] = pts }
      CamaleonCms::UserRole::ROLES[:manager].each { |value| m[value[:key]] = 1 }
      user_role.set_meta("_post_type_#{self.id}", d || {})
      user_role.set_meta("_manager_#{self.id}", m || {})
    end

    user_role = self.user_roles.where({slug: 'editor'}).first_or_create({name: 'Editor', description: 'Editor Role'})
    if user_role.valid?
      d = {}
      if post_type.present?
        d = user_role.get_meta("_post_type_#{self.id}", {})
        CamaleonCms::UserRole::ROLES[:post_type].each { |value|
          value_old = d[value[:key].to_sym] || []
          d[value[:key].to_sym] = value_old + [post_type.id]
        }
      else
        pts = self.post_types.all.pluck(:id)
        CamaleonCms::UserRole::ROLES[:post_type].each { |value| d[value[:key]] = pts }
      end
      user_role.set_meta("_post_type_#{self.id}", d || {})
    end

    user_role = self.user_roles.where({slug: 'contributor'}).first_or_create({name: 'Contributor', description: 'Contributor Role'})
    if user_role.valid?
      d = {}
      if post_type.present?
        d = user_role.get_meta("_post_type_#{self.id}", {})
        CamaleonCms::UserRole::ROLES[:post_type].each { |value|
          value_old = d[value[:key].to_sym] || []
          d[value[:key].to_sym] = value_old + [post_type.id] if value[:key].to_s == 'edit'
        }
      else
        pts = self.post_types.all.pluck(:id)
        CamaleonCms::UserRole::ROLES[:post_type].each { |value| d[value[:key]] = pts if value[:key].to_s == 'edit' }
      end
      user_role.set_meta("_post_type_#{self.id}", d || {})
    end

    unless post_type.present?
      user_role = self.user_roles.where({slug: 'client', term_group: -1}).first_or_create({name: 'Client', description: 'Default roles client'})
      if user_role.valid?
        user_role.set_meta("_post_type_#{self.id}", {})
        user_role.set_meta("_manager_#{self.id}", {})
      end
    end

  end
end
