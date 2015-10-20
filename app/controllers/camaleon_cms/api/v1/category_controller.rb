class CamaleonCms::Api::V1::CategoryController < Api::ApiController

  swagger_controller :categories, 'Categories'

  swagger_api :categories do
    summary 'Categories'
    notes 'Notes...'
  end

  def categories
    render json: current_site.full_categories
  end

end
