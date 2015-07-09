class Plugins::Ecommerce::Admin::PricesController < Plugins::Ecommerce::AdminController
  before_action :set_shipping_method

  def index
    admin_breadcrumb_add("#{t('plugin.ecommerce.product.price')}")
  end

  def new
    @price = {}
    admin_breadcrumb_add("#{t('plugin.ecommerce.product.price')}", admin_plugins_ecommerce_shipping_method_prices_path( params[:shipping_method_id] ))
    admin_breadcrumb_add("#{t('plugin.ecommerce.new')}")
    render 'form'
  end

  def show
  end

  def edit
    @price = @prices[params[:id].to_sym] || {}
    admin_breadcrumb_add("#{t('plugin.ecommerce.product.price')}", admin_plugins_ecommerce_shipping_method_prices_path( params[:shipping_method_id] ))
    admin_breadcrumb_add("#{t('admin.button.edit')}")
    render 'form'
  end

  def create
    _id = Time.now.to_i.to_s
    data = params[:price]
    data[:id] = _id
    @prices[_id] = data
    @shipping_method.set_meta('prices', @prices)
    flash[:notice] = t('admin.post_type.message.created')
    redirect_to action: :index
  end

  def update
    _id = params[:id]
    @price = @prices[params[:id].to_sym] || {}
    @prices[_id] = @price.merge(params[:price])
    @shipping_method.set_meta('prices', @prices)
    flash[:notice] = t('admin.post_type.message.updated')
    redirect_to action: :index
  end

  def destroy
    @prices.delete(params[:id].to_sym)
    @shipping_method.set_meta('prices', @prices)
    flash[:notice] = t('admin.post_type.message.deleted')
    redirect_to action: :index
  end



  private
  def set_shipping_method
    @shipping_method = current_site.shipping_methods.find(params[:shipping_method_id])
    @prices = @shipping_method.meta[:prices] || {}
  end

end
