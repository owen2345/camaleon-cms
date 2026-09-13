module CamaleonCms
  module Admin
    # Shared by PostsController and Settings::PostTypesController: which template/layout names a save may
    # carry. Both write values the frontend renders through `lookup_context.template_exists?` (a post's
    # own `meta[template]`/`meta[layout]`, or the post type's `default_template`/`default_layout` that a
    # post falls back to), so both hold a non-admin to the names the post editor actually offers.
    module PostViewChoicesConcern
      extend ActiveSupport::Concern

      private

      # A blank value (the editor submits blank when nothing is chosen), or one of the template/layout
      # names the post editor offers for `post_type`. A Hash or an Array in this position is never offered.
      def cama_offered_view_choice?(value, lister, post_type)
        return true if value.blank?
        return false unless value.is_a?(String)

        cama_offered_view_choices(lister, post_type).include?(value)
      end

      # The theme's post templates or layouts as the editor lists them (hooks included), reduced to the
      # value a chosen option submits -- an entry may be a plain name, a [label, value] pair or a Hash.
      # Memoized per request per lister.
      def cama_offered_view_choices(lister, post_type)
        cama_cache_fetch("offered_post_#{lister}") do
          send(lister, post_type).to_a.map { |entry| (entry.is_a?(Array) ? entry.last : entry).to_s }
        end
      end
    end
  end
end
