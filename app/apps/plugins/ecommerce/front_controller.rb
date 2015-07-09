class Plugins::Ecommerce::FrontController < Apps::PluginsFrontController
  before_action :ecommerce_add_assets_in_front
  def index
    # here your actions for frontend module
  end

  def product

  end
end