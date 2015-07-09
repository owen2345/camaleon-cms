module Plugins::SocialLogin::SocialLoginFunctionsHelper

  # This verifies if a user is linked to a social network
  def social_present(social, user_id)
    current_site.social_login.where(["provider = ? and user_id = ?", social, user_id]).first()
  end
end