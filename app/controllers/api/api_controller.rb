class Api::ApiController < CamaleonController
  #before_action -> { doorkeeper_authorize! :client }

  def account
    render json: current_user
  end

  def render_json_error(internal_message = 'Unexpected error', code = 100, status = 404, user_message = 'Unexpected error')
    error = {
        'userMessage': user_message,
        'internalMessage': internal_message,
        'code': code
    }
    render :json => error, :status => status
  end

  def render_json_ok(message = 'Success', status = 200, more_info = {})
    msg = {
        message: message,
        more_info: more_info
    }
    render :json => msg, :status => status
  end

end