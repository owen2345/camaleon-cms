class Admin::Appearances::Widgets::MainController < Admin::AppearancesController
  before_action :check_permission_role

  def index
    @widgets = current_site.widgets
  end

  def new
    @widget ||= current_site.widgets.new
    render "form", layout: false
  end

  def edit
    @widget = current_site.widgets.find(params[:id])
    new
  end

  def create
    params[:widget_main][:status] = "simple"
    @widget = current_site.widgets.new(params[:widget_main])
    if @widget.save!
      flash[:notice] = t('admin.widgets.message.created')
    else
      flash[:error] = t('admin.widgets.message.error_created')
    end
    redirect_to action: :index
  end

  def update
    @widget = current_site.widgets.find(params[:id])
    if @widget.update!(params[:widget_main])
      flash[:notice] = t('admin.widgets.message.updated')
    else
      flash[:error] = t('admin.widgets.message.error_updated')
    end
    redirect_to action: :index
  end

  def destroy
    @widget = current_site.widgets.find(params[:id]).destroy!
    flash[:notice] = t('admin.widgets.message.deleted')
    redirect_to action: :index
  end

  private
  def check_permission_role
    authorize! :manager, :widgets
  end
end