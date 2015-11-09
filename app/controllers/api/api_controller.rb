class Api::ApiController < CamaleonController
  include ApiHelper
  #before_action -> { doorkeeper_authorize! :client }
  def account
    render json: current_user
  end

  def render_json_error(error, status = 404)
    render json: error, status: status
  end

  def render_json_ok(message = 'Success', status = 200, more_info = {})
    msg = {
        message: message,
        more_info: more_info
    }
    render json: msg, status: status
  end

  def render_json_not_found
    render nothing: true, status: 404
  end

  def render_api_error(api_error)
    error = {
        :code => api_error[:code],
        :text => api_error[:text],
        :description => api_error[:description]
    }
    render_json_error(error, api_error[:status])
  end

  def self.add_swagger_response_code(api, error)
    api.response error[:code], error[:text]
  end
end
