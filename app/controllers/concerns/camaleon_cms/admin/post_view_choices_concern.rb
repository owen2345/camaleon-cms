module CamaleonCms
  module Admin
    # Shared by PostsController and Settings::PostTypesController: which template/layout names a save may
    # carry. Both write values the frontend renders through `lookup_context.template_exists?` (a post's
    # own `meta[template]`/`meta[layout]`, or the `default_template`/`default_layout` a post falls back
    # to, from its own options or its post type's), so both hold a non-admin to the names the post
    # editor actually offers. The concern owns the fields, the offered lists and the refusal.
    module PostViewChoicesConcern
      extend ActiveSupport::Concern

      # The template and layout fields a save can carry, each with the helper that lists what the post
      # editor offers for it. Keys are the canonical (folded) field names.
      POST_VIEW_LISTERS = { 'template' => :cama_get_list_template_files,
                            'layout' => :cama_get_list_layouts_files }.freeze
      DEFAULT_VIEW_LISTERS = { 'default_template' => :cama_get_list_template_files,
                               'default_layout' => :cama_get_list_layouts_files }.freeze

      included do
        helper_method :cama_post_view_list
      end

      private

      # The list a lister returns for `post_type`, as the editor renders it: memoized per request per
      # lister, so the check and the re-rendered form's selects share one theme glob and one hook
      # dispatch (one post type per request).
      def cama_post_view_list(lister, post_type)
        cama_cache_fetch("post_view_list_#{lister}") { send(lister, post_type) }
      end

      # The refusal message for `field` (as the request names it) holding `value`, when the acting user
      # is not an administrator and `value` is not blank or offered by `lister` for `post_type`; nil
      # when the value may be stored.
      def cama_unoffered_view_choice_refusal(field, value, lister, post_type)
        return if cama_current_user.admin? || cama_offered_view_choice?(value, lister, post_type)

        cama_post_message('value_not_offered', field: field)
      end

      # A blank value (the editor submits blank when nothing is chosen), or one of the template/layout
      # names the post editor offers for `post_type`. A Hash or an Array in this position is never offered.
      def cama_offered_view_choice?(value, lister, post_type)
        return true if value.blank?
        return false unless value.is_a?(String)

        cama_offered_view_choices(lister, post_type).include?(value)
      end

      # The theme's post templates or layouts as the editor lists them (hooks included), reduced to the
      # values the editor's select would submit. A list given as pre-rendered option markup (a String,
      # which options_for_select renders verbatim) offers nothing: its values are unknowable. Memoized
      # per request per lister.
      def cama_offered_view_choices(lister, post_type)
        cama_cache_fetch("offered_post_#{lister}") do
          list = cama_post_view_list(lister, post_type)
          list.is_a?(String) ? [] : Array(list).flat_map { |entry| cama_view_choice_values(entry) }
        end
      end

      # The value(s) one select entry submits, derived as Rails' option_text_and_value derives them:
      # trailing Hash elements are HTML attributes, the last remaining element of an Array entry is the
      # value (`[text, value]`, or `[value]`), a grouped entry (`[label, [entries]]`) offers its inner
      # entries, and anything else is its own value.
      def cama_view_choice_values(entry)
        return [entry.to_s] unless entry.is_a?(Array)

        entry = entry.reject { |element| element.is_a?(Hash) }
        return [] if entry.empty?

        value = entry.last
        value.is_a?(Array) ? value.flat_map { |inner| cama_view_choice_values(inner) } : [value.to_s]
      end

      # Only en.yml carries the post editor's messages while the process locale follows the admin
      # language, so they resolve through the English fallback.
      def cama_post_message(key, **vars)
        cama_t("camaleon_cms.admin.post.message.#{key}", vars)
      end
    end
  end
end
