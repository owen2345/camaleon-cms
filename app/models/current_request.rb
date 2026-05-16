# CurrentRequest holds per-request state (user, site) accessible to models
# via ActiveSupport::CurrentAttributes (thread-safe, resets after each request).
#
# Usage in controllers:
#   CurrentRequest.user = cama_current_user
#   CurrentRequest.site = current_site
#
# Usage in models:
#   current_user  # delegates to CurrentRequest.user via CamaleonRecord
#   current_site  # delegates to CurrentRequest.site via CamaleonRecord
#
# Note: Rails automatically resets CurrentAttributes between requests, ensuring no leakage.
# In specs, call CurrentRequest.reset in before/after hooks to avoid cross-test pollution.
class CurrentRequest < ActiveSupport::CurrentAttributes
  attribute :user, :site, :content_helper_state, :hooks_helper_state, :html_helper_state, :theme_helper_state,
            :frontend_object, :frontend_seo_settings, :frontend_current_theme, :frontend_site_current_path,
            :frontend_visited_home, :frontend_visited_post, :frontend_visited_ajax, :frontend_visited_search,
            :frontend_visited_post_type, :frontend_visited_tag, :frontend_visited_category,
            :frontend_visited_profile, :frontend_user,
            :admin_menu_items, :custom_field_elements, :extra_models_for_fields
end
