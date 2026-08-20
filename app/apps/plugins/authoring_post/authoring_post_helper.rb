module Plugins
  module AuthoringPost
    module AuthoringPostHelper
      def plugin_authoring_post_the_content(args); end

      def plugin_authoring_on_active(plugin); end

      def plugin_authoring_on_inactive(plugin); end

      def plugin_authoring_post_list(args); end

      def plugin_authoring_create_post(args); end

      def plugin_authoring_new_post(args)
        args[:extra_settings] << plugin_authoring_form_html(args[:post])
      end

      def plugin_authoring_can_visit(args); end

      def plugin_authoring_extra_columns(args); end

      def plugin_authoring_filter_post(args); end

      private

      def plugin_authoring_form_html(post)
        disabled = !(can?(:edit_other, post.post_type) && (can?(:edit_publish, post.post_type) || !post.published?))

        label = tag.label(t('camaleon_cms.admin.table.author'), class: 'control-label')
        select = content_tag(
          :select,
          safe_join(plugin_authoring_authors_list(post)),
          id: 'post_user_id', name: 'post[user_id]',
          class: 'form-control select valid',
          disabled: disabled,
          'aria-invalid' => 'false'
        )

        tag.div(safe_join([label, select]), class: 'form-group')
      end

      def plugin_authoring_authors_list(post)
        author_id = post.new_record? ? cama_current_user.id : post.author.id

        current_site.users.where('role <> ?', 'client').order(:username).map do |user|
          selected = user.id == author_id
          titleized_username = user.username.titleize
          display = if user.fullname == titleized_username
                      titleized_username
                    else
                      "#{titleized_username} (#{user.fullname})"
                    end
          tag.option(display, value: user.id, selected: selected)
        end
      end
    end
  end
end
