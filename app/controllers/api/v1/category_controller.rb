class Api::V1::CategoryController < Api::ApiController

  def categories
    render json: current_site.full_categories
  end

end
