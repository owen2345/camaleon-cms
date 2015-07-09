Rails.application.config.middleware.use OmniAuth::Builder do
  provider :twitter, :setup => true
  provider :facebook, :setup => true
  provider :google_oauth2, :setup => true
end