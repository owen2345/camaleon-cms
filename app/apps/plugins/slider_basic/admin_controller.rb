class Plugins::SliderBasic::AdminController < Apps::PluginsAdminController
  before_action :set_order, only: ['show','edit','update','destroy']

  def index
    @slider_basics = current_site.slider_basics.paginate(:page => params[:page], :per_page => current_site.admin_per_page)
  end

  def new
    @slider_basic = current_site.slider_basics.new
    render 'form'
  end

  def show
  end

  def edit
    admin_breadcrumb_add("#{t('admin.button.edit')}")
    render 'form'
  end

  def create
    data = params[:plugins_slider_basic_models_slider_basic]
    @slider_basic = current_site.slider_basics.new(data)
    if @slider_basic.save
      @slider_basic.set_field_values(params[:field_options])
      flash[:notice] = t('admin.post_type.message.created')
      redirect_to action: :index
    else
      render 'form'
    end
  end

  def destroy
    current_site.slider_basics.find(params[:id]).destroy
    flash[:notice] = t('admin.post_type.message.destroyed')
    redirect_to action: :index
  end

  def update
    data = params[:plugins_slider_basic_models_slider_basic]
    if @slider_basic.update(data)
      @slider_basic.set_field_values(params[:field_options])
      flash[:notice] = t('admin.post_type.message.updated')
      redirect_to action: :index
    else
      render 'form'
    end
  end




  private
  def set_order
    @slider_basic = current_site.slider_basics.find(params[:id])
  end

end