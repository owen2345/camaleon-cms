module Plugins
  module VisibilityPost
    class FrontController < CamaleonCms::Apps::PluginsFrontController
      # Security (audit M2): unlocks a password-protected post for the current session. Replaces
      # the old GET `post_password` parameter flow, which put the password in URLs, logs and
      # referrers and compared it with `==`. The password travels in a POST body, is compared in
      # constant time, and the unlocked state is a session-side marker -- never the password.
      def unlock
        post = current_site.the_posts.where(id: params[:post_id]).first
        return page_not_found if post.blank? || post.visibility != 'password'

        submitted = params[:post_password].to_s
        if submitted.present? && ActiveSupport::SecurityUtils.secure_compare(submitted, post.visibility_value.to_s)
          session[VisibilityPostHelper::SESSION_UNLOCKED_KEY] =
            Array(session[VisibilityPostHelper::SESSION_UNLOCKED_KEY]) | [post.id]
        else
          flash[:cama_visibility_post_error] = true
        end
        redirect_to post.decorate.the_url(as_path: true)
      end
    end
  end
end
