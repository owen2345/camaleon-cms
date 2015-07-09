class Plugins::Ecommerce::Admin::TaxRatesController < Plugins::Ecommerce::AdminController
  before_action :set_order, only: ['show','edit','update','destroy']

  def index
    @tax_rates = current_site.tax_rates.paginate(:page => params[:page], :per_page => current_site.admin_per_page)
  end

  def new
    @tax_rate = current_site.tax_rates.new
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
    data = params[:plugins_ecommerce_models_tax_rate]
    @tax_rate = current_site.tax_rates.new(data)
    if @tax_rate.save
      @tax_rate.set_meta('_default', params[:options])
      flash[:notice] = t('admin.post_type.message.created')
      redirect_to action: :index
    else
      render 'form'
    end
  end

  def update
    data = params[:plugins_ecommerce_models_tax_rate]
    if @tax_rate.update(data)
      @tax_rate.set_meta('_default', params[:options])
      flash[:notice] = t('admin.post_type.message.updated')
      redirect_to action: :index
    else
      render 'form'
    end
  end




  private
  def set_order
    @tax_rate = current_site.tax_rates.find(params[:id])
  end

end
