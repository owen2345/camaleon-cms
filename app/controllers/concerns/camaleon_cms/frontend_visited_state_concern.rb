module CamaleonCms
  module FrontendVisitedStateConcern
    extend ActiveSupport::Concern

    LEGACY_VISITED_IVAR_BY_ATTR = {
      frontend_visited_home: :@cama_visited_home,
      frontend_visited_post: :@cama_visited_post,
      frontend_visited_ajax: :@cama_visited_ajax,
      frontend_visited_search: :@cama_visited_search,
      frontend_visited_post_type: :@cama_visited_post_type,
      frontend_visited_tag: :@cama_visited_tag,
      frontend_visited_category: :@cama_visited_category,
      frontend_visited_profile: :@cama_visited_profile
    }.freeze

    private

    def mark_frontend_home_visited
      set_frontend_visited_state(:frontend_visited_home, true)
    end

    def mark_frontend_post_visited(post)
      set_frontend_visited_state(:frontend_visited_post, post)
    end

    def mark_frontend_ajax_visited
      set_frontend_visited_state(:frontend_visited_ajax, true)
    end

    def mark_frontend_search_visited
      set_frontend_visited_state(:frontend_visited_search, true)
    end

    def mark_frontend_post_type_visited(post_type)
      set_frontend_visited_state(:frontend_visited_post_type, post_type)
    end

    def mark_frontend_tag_visited(post_tag)
      set_frontend_visited_state(:frontend_visited_tag, post_tag)
    end

    def mark_frontend_category_visited(category)
      set_frontend_visited_state(:frontend_visited_category, category)
    end

    def mark_frontend_profile_visited(user = nil)
      set_frontend_visited_state(:frontend_visited_profile, true)
      CurrentRequest.frontend_user = user if user.present?
    end

    def set_frontend_visited_state(current_request_attr, value)
      CurrentRequest.public_send("#{current_request_attr}=", value)
      legacy_ivar = LEGACY_VISITED_IVAR_BY_ATTR[current_request_attr]
      return if legacy_ivar.blank?

      instance_variable_set(legacy_ivar, value)
      warn_frontend_legacy_visited_ivar(legacy_ivar, current_request_attr)
    end

    def warn_frontend_legacy_visited_ivar(legacy_ivar, current_request_attr)
      warned_legacy_ivars = self.class.instance_variable_get(:@_warned_frontend_legacy_visited_ivars) || {}
      return if warned_legacy_ivars[legacy_ivar]

      ActiveSupport::Deprecation._instance.warn(
        "Controller compatibility ivar #{legacy_ivar} is deprecated and will be removed in a future major release. " \
        "Use CurrentRequest.#{current_request_attr} instead."
      )
      warned_legacy_ivars[legacy_ivar] = true
      self.class.instance_variable_set(:@_warned_frontend_legacy_visited_ivars, warned_legacy_ivars)
    end
  end
end
