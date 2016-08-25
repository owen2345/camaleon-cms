class CamaleonCms::Admin::Appearances::Widgets::MainController < CamaleonCms::AdminController
  before_action :check_permission_role
  before_action :set_widgets, only: [:edit, :update, :destroy]
  add_breadcrumb I18n.t("camaleon_cms.admin.sidebar.appearance")
  add_breadcrumb I18n.t("camaleon_cms.admin.sidebar.widgets")

  def index
    @widgets = current_site.widgets
  end

  def new
    @widget ||= current_site.widgets.new
    render "form", layout: false
  end

  def edit
    new
  end

  def create
    params[:widget_main][:status] = "simple"
    @widget = current_site.widgets.new(params.require(:widget_main).permit!)
    if @widget.save!
      flash[:notice] = t('camaleon_cms.admin.widgets.message.created')
    else
      flash[:error] = t('camaleon_cms.admin.widgets.message.error_created')
    end
    redirect_to action: :index
  end

  def update
    if @widget.update!(params.require(:widget_main).permit!)
      flash[:notice] = t('camaleon_cms.admin.widgets.message.updated')
    else
      flash[:error] = t('camaleon_cms.admin.widgets.message.error_updated')
    end
    redirect_to action: :index
  end

  def destroy
    @widget = @widget.destroy!
    flash[:notice] = t('camaleon_cms.admin.widgets.message.deleted')
    redirect_to action: :index
  end

  private

  def set_widgets
    @widget = current_site.widgets.find(params[:id])
  end

  def check_permission_role
    authorize! :manage, :widgets
  end
end
