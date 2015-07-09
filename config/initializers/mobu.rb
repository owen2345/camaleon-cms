# this is a mobu customization to add prefixes for views and not use another views directory
module Mobu
  module DetectMobile
    extend ActiveSupport::Concern

    private
    def check_mobile_site
      case params.delete(:prefer)
        when "f"
          session[:prefer_full_site] = 1
        when "m"
          session.delete :prefer_full_site
      end

      if mobile_request?
        # prepend_view_path mobile_views_path
        lookup_context.prefixes.prepend("mobile") if !lookup_context.prefixes.include?("mobile")
      elsif tablet_request?
        # prepend_view_path tablet_views_path
        lookup_context.prefixes.prepend("tablet") if !lookup_context.prefixes.include?("tablet")
      end
    end
  end
end
