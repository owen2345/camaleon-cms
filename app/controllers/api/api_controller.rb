class Api::ApiController < ActionController::Base
  include CamaleonHelper
  include SessionHelper
  include SiteHelper
  include HtmlHelper
  include UserRolesHelper
  include ShortCodeHelper
  include PluginsHelper
  include ThemeHelper
  include HooksHelper
  include ContentHelper
  include CaptchaHelper
  include UploaderHelper

  before_action -> { doorkeeper_authorize! :client }
  respond_to :json

  def account
    render json: current_resource_owner
  end

  private

  def current_resource_owner
    User.find(doorkeeper_token.resource_owner_id) if doorkeeper_token
  end

end
