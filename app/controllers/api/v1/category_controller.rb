class Api::V1::CategoryController < Api::ApiController

  swagger_controller :categories, 'Categories'

  swagger_api :categories do
    summary 'Categories'
    notes 'Notes...'
  end

  def categories
    @categories = current_site.full_categories
    render json: ActiveModel::ArraySerializer.new(@categories, each_serializer: Api::V1::CategorySerializer)
  end

end
