module CamaleonCms
  module SiteDefaultSettings
    extend ActiveSupport::Concern
    # default structure for each new site
    def default_settings
      default_post_type = [
        {
          name: 'Post', description: 'Posts',
          options: {
            has_category: true, has_tags: true, not_deleted: true, has_summary: true, has_content: true,
            has_comments: true, has_picture: true, has_template: true
          }
        },
        {
          name: 'Page', description: 'Pages',
          options: {
            has_category: false, has_tags: false, not_deleted: true, has_summary: false, has_content: true,
            has_comments: false, has_picture: true, has_template: true, has_layout: true
          }
        }
      ]
      default_post_type.each do |pt|
        post_types.create({ name: pt[:name], slug: pt[:name].to_s.parameterize, description: pt[:description],
                            data_options: pt[:options] })
      end

      # nav menus
      @nav_menu = nav_menus.new({ name: 'Main Menu', slug: 'main_menu' })
      if @nav_menu.save
        post_types.find_each do |pt|
          if pt.slug == 'post'
            title = 'Sample Post'
            slug = 'sample-post'
            content_parts = []
            content_parts << helpers.content_tag(
              :p, 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Integer pharetra ut augue in posuere. ' \
                  'Nulla non malesuada dui. Sed egestas tortor ut purus tempor sodales. ' \
                  'Duis non sollicitudin nulla, quis mollis neque. Integer sit amet augue ac neque varius auctor. ' \
                  'Vestibulum malesuada leo leo, at semper libero efficitur nec. ' \
                  'Etiam semper nisi ac nisi ullamcorper, sed tincidunt purus elementum. ' \
                  'Mauris ac congue nibh. Quisque pretium eget leo nec suscipit.'
            )
            content_parts << helpers.content_tag(
              :p, 'Vestibulum ultrices orci ut congue interdum. ' \
                   'Morbi dolor nunc, imperdiet vel risus semper, tempor dapibus urna. ' \
                   'Phasellus luctus pharetra enim quis volutpat. Integer tristique urna nec malesuada ullamcorper. ' \
                   'Curabitur dictum, lectus id ultrices rhoncus, ante neque auctor erat, ' \
                   'ut sodales nisi odio sit amet lorem. In hac habitasse platea dictumst. ' \
                   'Quisque orci orci, hendrerit at luctus tristique, lobortis in diam. ' \
                   'Curabitur ligula enim, rhoncus ut vestibulum a, consequat sit amet nisi. ' \
                   'Aliquam bibendum fringilla ultrices. Aliquam erat volutpat. ' \
                   'Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia Curae; ' \
                   'In justo mi, congue in rhoncus lobortis, facilisis in est. Nam et rhoncus purus.'
            )
            content_parts << helpers.content_tag(
              :p, 'Sed sagittis auctor lectus at rutrum. ' \
                  'Morbi ultricies felis mi, ut scelerisque augue facilisis eu. In molestie quam ex. ' \
                  'Quisque ut sapien sed odio tempus imperdiet. In id accumsan massa. ' \
                  'Morbi quis nunc ullamcorper, interdum enim eu, finibus purus. ' \
                  'Vestibulum ac fermentum augue, at tempus ante. ' \
                  'Aliquam ultrices, purus ut porttitor gravida, dui augue dignissim massa, ' \
                  'ac tempor ante dolor at arcu. ' \
                  'Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas. ' \
                  'Suspendisse placerat risus est, eget varius mi ultricies in. ' \
                  'Duis non odio ut felis dapibus eleifend. In fringilla enim lobortis placerat efficitur.'
            )
            content_parts << helpers.content_tag(
              :p, 'Nulla sodales faucibus urna, quis viverra dolor facilisis sollicitudin. Aenean ac egestas nibh. ' \
                  'Nam non tortor eget nibh scelerisque fermentum. ' \
                  'Etiam ornare, nunc ut luctus mollis, ante dolor consectetur augue, ' \
                  'non scelerisque odio est a nulla. Nullam cursus egestas nulla, nec commodo nibh suscipit ut. ' \
                  'Mauris ut felis sem. Aenean at mi at nisi dictum blandit sit amet at erat. ' \
                  'Etiam eget lobortis tellus. Curabitur in commodo arcu, at vehicula tortor.'
            )
            content = helpers.safe_join(content_parts)
          else
            title = 'Welcome'
            slug = 'welcome'
            welcome_parts = []
            logo_img = helpers
                       .image_tag('https://camaleon.website/media/132/logo2.png', width: 155, height: 155, alt: 'logo')
            welcome_parts << helpers.content_tag(:p, logo_img, style: 'text-align: center;')
            cms_strong = helpers.content_tag(:strong, 'Camaleon CMS')
            rails_link = helpers.link_to('Ruby on Rails', 'https://rubyonrails.org')
            part2_text = helpers.safe_join(
              [
                cms_strong,
                ' is a free and open-source tool and a fexible content management system (CMS) based on ',
                rails_link
              ]
            )
            welcome_parts << helpers.content_tag(:p, part2_text)
            welcome_parts << helpers.content_tag(:p, 'With Camaleon you can do the following:')
            li_texts = [
              'Create instantly a lot of sites in the same installation',
              'Manage your content information in several languages',
              'Extend current functionality by plugins (MVC structure and no more echo or prints anywhere)',
              'Create or install different themes for each site',
              'Create your own structure without coding anything (adapt Camaleon as you want and not you for Camaleon)',
              'Create your store and start to sell your products using our plugins',
              'Avoid web attacks',
              'Compare the speed and enjoy the speed of your new Camaleon site',
              'Customize or create your themes for mobile support',
              'Support more visitors at the same time',
              'Manage your information with a panel like wordpress ',
              'All urls are oriented for SEO',
              'Multiples roles of users'
            ]
            li_tags = li_texts.map { |text| helpers.content_tag(:li, text) }
            welcome_parts << helpers.content_tag(:ul, helpers.safe_join(li_tags))
            content = helpers.safe_join(welcome_parts)
          end
          user = users.admin_scope.first
          if user.blank?
            user = users.admin_scope.create({ email: 'admin@local.com', username: 'admin', password: 'admin123',
                                              password_confirmation: 'admin123', first_name: 'Administrator' })
          end
          post = pt.add_post({ title: title, slug: slug, content: content, user_id: user.id, status: 'published' })
          @nav_menu.append_menu_item({ label: title, type: 'post', link: post.id })
        end
      end
      get_anonymous_user
    end

    # auto create default user roles
    def set_default_user_roles(post_type = nil)
      user_role = user_roles.where({ slug: 'admin',
                                     term_group: -1 }).first_or_create({ name: 'Administrator',
                                                                         description: 'Default roles admin' })
      if user_role.valid?
        d = {}
        m = {}
        pts = post_types.all.pluck(:id)
        CamaleonCms::UserRole::ROLES[:post_type].each { |value| d[value[:key]] = pts }
        CamaleonCms::UserRole::ROLES[:manager].each { |value| m[value[:key]] = 1 }
        user_role.set_meta("_post_type_#{id}", d || {})
        user_role.set_meta("_manager_#{id}", m || {})
      end

      user_role = user_roles.where({ slug: 'editor' }).first_or_create({ name: 'Editor', description: 'Editor Role' })
      if user_role.valid?
        d = {}
        if post_type.present?
          d = user_role.get_meta("_post_type_#{id}", {})
          CamaleonCms::UserRole::ROLES[:post_type].each do |value|
            # allow_unfiltered_html lets a role store unsanitized HTML in post content; it must not be
            # granted to the default Editor role (only admins, via `can :manage, :all`, are trusted for it).
            next if value[:key].to_s == 'allow_unfiltered_html'

            value_old = d[value[:key].to_sym] || []
            d[value[:key].to_sym] = value_old + [post_type.id]
          end
        else
          pts = post_types.all.pluck(:id)
          CamaleonCms::UserRole::ROLES[:post_type].each do |value|
            next if value[:key].to_s == 'allow_unfiltered_html'

            d[value[:key]] = pts
          end
        end
        user_role.set_meta("_post_type_#{id}", d || {})
      end

      user_role = user_roles.where({ slug: 'contributor' })
                            .first_or_create({ name: 'Contributor', description: 'Contributor Role' })
      if user_role.valid?
        d = {}
        if post_type.present?
          d = user_role.get_meta("_post_type_#{id}", {})
          CamaleonCms::UserRole::ROLES[:post_type].each do |value|
            value_old = d[value[:key].to_sym] || []
            d[value[:key].to_sym] = value_old + [post_type.id] if value[:key].to_s == 'edit'
          end
        else
          pts = post_types.all.pluck(:id)
          CamaleonCms::UserRole::ROLES[:post_type].each { |value| d[value[:key]] = pts if value[:key].to_s == 'edit' }
        end
        user_role.set_meta("_post_type_#{id}", d || {})
      end

      return if post_type.present?

      user_role = user_roles.where({ slug: 'client', term_group: -1 })
                            .first_or_create({ name: 'Client', description: 'Default roles client' })
      return unless user_role.valid?

      user_role.set_meta("_post_type_#{id}", {})
      user_role.set_meta("_manager_#{id}", {})
    end

    private

    def helpers
      ActionController::Base.helpers
    end
  end
end
