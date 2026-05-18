module CamaleonCms
  module FrontendVisitedStateConcern
    extend ActiveSupport::Concern

    private

    def mark_frontend_home_visited
      set_frontend_visited_state(:frontend_visited_home, :@cama_visited_home, true)
    end

    def mark_frontend_post_visited(post)
      set_frontend_visited_state(:frontend_visited_post, :@cama_visited_post, post)
    end

    def mark_frontend_ajax_visited
      set_frontend_visited_state(:frontend_visited_ajax, :@cama_visited_ajax, true)
    end

    def mark_frontend_search_visited
      set_frontend_visited_state(:frontend_visited_search, :@cama_visited_search, true)
    end

    def mark_frontend_post_type_visited(post_type)
      set_frontend_visited_state(:frontend_visited_post_type, :@cama_visited_post_type, post_type)
    end

    def mark_frontend_tag_visited(post_tag)
      set_frontend_visited_state(:frontend_visited_tag, :@cama_visited_tag, post_tag)
    end

    def mark_frontend_category_visited(category)
      set_frontend_visited_state(:frontend_visited_category, :@cama_visited_category, category)
    end

    def mark_frontend_profile_visited(user = nil)
      set_frontend_visited_state(:frontend_visited_profile, :@cama_visited_profile, true)
      CurrentRequest.frontend_user = user if user.present?
    end

    def set_frontend_visited_state(current_request_attr, legacy_ivar, value)
      CurrentRequest.public_send("#{current_request_attr}=", value)
      instance_variable_set(legacy_ivar, value)
    end
  end
end
