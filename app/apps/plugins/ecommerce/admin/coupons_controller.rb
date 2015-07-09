class Plugins::Ecommerce::Admin::CouponsController < Plugins::Ecommerce::AdminController
  before_action :set_order, only: ['show','edit','update','destroy']

  def index
    @coupons = current_site.coupons.paginate(:page => params[:page], :per_page => current_site.admin_per_page)
  end

  def new
    @coupon = current_site.coupons.new
    admin_breadcrumb_add("#{t('plugin.ecommerce.new')}")
    render 'form'
  end

  def show
  end

  def edit
    admin_breadcrumb_add("#{t('admin.button.edit')}")
    render 'form'
  end

  def create
    data = params[:plugins_ecommerce_models_coupon]
    @coupon = current_site.coupons.new(data)
    if @coupon.save
      @coupon.set_meta('_default', params[:options])
      flash[:notice] = t('admin.post_type.message.created')
      redirect_to action: :index
    else
      render 'form'
    end
  end

  def update
    data = params[:plugins_ecommerce_models_coupon]
    if @coupon.update(data)
      @coupon.set_meta('_default', params[:options])
      flash[:notice] = t('admin.post_type.message.updated')
      redirect_to action: :index
    else
      render 'form'
    end
  end




  private
  def set_order
    @coupon = current_site.coupons.find(params[:id])
  end

end
