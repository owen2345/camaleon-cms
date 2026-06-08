# frozen_string_literal: true

module Plugins
  module VisibilityPost
    module VisibilityPostHelper
      # {content: object.content.translate(@_deco_locale), post: object}
      def plugin_visibility_post_the_content(args)
        return unless args[:post].visibility == 'password'
        return if params[:post_password].present? && params[:post_password] == args[:post].visibility_value

        args[:content] = _password_form
      end

      def plugin_visibility_on_active(_plugin); end

      def plugin_visibility_on_inactive(_plugin); end

      def plugin_visibility_post_list(args)
        args[:posts] = args[:posts].where(visibility: 'private') if params[:s] == 'private'
        args[:btns][:private] =
          "#{t('camaleon_cms.admin.table.private')} (#{args[:all_posts].where(visibility: 'private').size})"
      end

      def plugin_visibility_create_post(args)
        save_visibility(args[:post])
      end

      def plugin_visibility_new_post(args)
        args[:extra_settings] << form_html(args[:post])
      end

      def plugin_visibility_can_visit(args)
        post = args[:post]
        return args[:flag] = false if post.published_at.present? && post.published_at > Time.zone.now
        return if post.visibility != 'private'

        args[:flag] = false unless signin? && post.visibility_value.split(',').include?(current_site.visitor_role)
      end

      def plugin_visibility_extra_columns(args)
        if args[:from_body]
          is_published = args[:post].published_at
          post_visibility = args[:post].visibility
          args[:content] =
            "<td><i class='fas fa-#{{ 'private' => 'lock', '' => 'lock', 'public' => 'eye',
                                      'password' => 'eye-slash' }[post_visibility]}'></i> #{post_visibility}</td>"
          args[:content] +=
            "<td>#{is_published.present? ? is_published.strftime('%B %e, %Y %H:%M') : args[:post].the_created_at}</td>"
        else
          args[:content] = "<th>#{t('camaleon_cms.admin.table.visibility')}</th>"
          args[:content] += "<th>#{t('camaleon_cms.admin.table.date_published')}</th>"
        end
      end

      def plugin_visibility_filter_post(args)
        db_table = CamaleonCms::Post.table_name
        args[:active_record] =
          args[:active_record].where(
            "(#{db_table}.published_at is null or #{db_table}.published_at <= ?)", Time.zone.now
          )
        not_private = "visibility != 'private'"
        args[:active_record] =
          if signin?
            if ActiveRecord::Base.connection.adapter_name.downcase.include?('mysql')
              args[:active_record].where(
                "#{not_private} or (visibility = 'private' and FIND_IN_SET(?, #{db_table}.visibility_value))",
                current_site.visitor_role
              )
            else
              args[:active_record].where(
                "#{not_private} or (visibility = 'private' and (',' || #{db_table}.visibility_value || ',') LIKE ?)",
                "%,#{current_site.visitor_role},%"
              )
            end
          else
            args[:active_record].where(not_private)
          end
      end

      private

      def _password_form
        "<form class='col-md-6 protected_form well'>
        <h4>#{ct('proceted_article', default: 'Protected article')}</h4>
        <div class='control-group'>
          <label class='control-label'>#{t('camaleon_cms.admin.post_type.enter_password')}:</label>
          <input type='text' name='post_password' value='' class='form-control' />
        </div>
        <div class='control-group'>
          <button class='btn btn-primary' type='submit'>#{ct('submit')}</button>
        </div>
    <form>"
      end

      def save_visibility(post)
        return unless post.visibility == 'private'

        post.visibility_value = params[:post_private_groups].join(',')
        post.save!
      end

      def form_html(post)
        append_asset_libraries({ 'plugin_visibility' => { js: [plugin_asset_path('js/form.js')] } })

        html = []
        html << tag.div(class: 'form-group') do
          tag.label(t('camaleon_cms.admin.post_type.published_date'), class: 'control-label') +
            tag.div(id: 'published_from', data: { locale: current_locale }, class: 'input-group date') do
              tag.input(
                name: 'post[published_at]', data: { format: 'yyyy-MM-dd hh:mm:ss' },
                class: 'form-control ', value: @post[:published_at]
              ) +
                tag.span(class: 'add-on input-group-addon') { tag.span(class: 'fas fa-calendar') }
            end
        end

        html << tag.div(id: 'panel-post-visibility', class: 'form-group') do
          tag.label(class: 'control-label') do
            "#{t('camaleon_cms.admin.table.visibility')}: ".html_safe + tag.span(class: 'visibility_label')
          end << ' - ' <<
            tag.a(href: '#') { tag.span(t('camaleon_cms.admin.button.edit'), 'aria-hidden': 'true') } <<
            tag.div(class: 'panel-options hidden') do
              public_checked = post.visibility.blank? || post.visibility == 'public'
              private_checked = post.visibility == 'private'
              password_checked = post.visibility == 'password'

              result = []
              result << tag.label(style: 'display: block;') do
                tag.input(
                  name: 'post[visibility]', class: 'radio', type: 'radio', value: 'public', checked: public_checked
                ) + " #{t('camaleon_cms.admin.table.public')}"
              end
              result << tag.div

              result << tag.label(style: 'display: block;') do
                tag.input(
                  name: 'post[visibility]', class: 'radio', type: 'radio', value: 'private', checked: private_checked
                ) + " #{t('camaleon_cms.admin.table.private')}"
              end

              result << tag.div(style: 'padding-left: 20px;') { groups_list(post) }

              result << tag.label(style: 'display: block;') do
                tag.input(
                  name: 'post[visibility]', class: 'radio', type: 'radio',
                  value: 'password', checked: password_checked
                ) + " #{t('camaleon_cms.admin.table.password_protection')}"
              end

              result << tag.div do
                tag.input(
                  name: 'post[visibility_value]', class: 'form-control password_field_value', type: 'text',
                  value: post.visibility == 'password' ? post.visibility_value : nil
                )
              end

              result << tag.p { tag.a(t('camaleon_cms.admin.table.hide'), class: 'lnk_hide', href: '#') }

              safe_join(result)
            end
        end

        safe_join(html)
      end

      def groups_list(post)
        current_groups = post.visibility == 'private' && post.visibility_value ? post.visibility_value.split(',') : []
        elements = []
        current_site.user_roles.each do |role|
          checked = current_groups.include?(role.slug.to_s)
          input = tag.input(
            type: 'checkbox',
            name: 'post_private_groups[]',
            class: 'visibility_private_group_item',
            value: role.slug,
            checked: checked
          )
          label = tag.label { safe_join([input, " #{role.name}"]) }
          elements << label
          elements << tag.br
        end
        safe_join(elements)
      end
    end
  end
end
