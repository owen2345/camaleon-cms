class CamaleonCms::Admin::Appearances::Widgets::SidebarController < CamaleonCms::AdminController
  before_action :check_permission_role
  before_action :set_sidebar, only: [:edit, :update, :destroy]

  def new
    @sidebar ||= current_site.sidebars.new
    render 'form', layout: false
  end

  def create
    @sidebar = current_site.sidebars.new(params.require(:widget_sidebar).permit!)
    if @sidebar.save
      flash[:notice] = t('camaleon_cms.admin.widgets.sidebar.created')
    else
      flash[:error] = t('camaleon_cms.admin.widgets.sidebar.error_created')
    end
    redirect_to cama_admin_appearances_widgets_main_index_path
  end

  def edit
    new
  end

  def update
    if @sidebar.update(params.require(:widget_sidebar).permit!)
      flash[:notice] = t('camaleon_cms.admin.widgets.sidebar.updated')
    else
      flash[:error] = t('camaleon_cms.admin.widgets.sidebar.error_updated')
    end
    redirect_to cama_admin_appearances_widgets_main_index_path
  end

  def reorder
    params[:pos].each_with_index do |assigned_id, index|
      current_site.sidebars.find(params[:sidebar_id]).assigned.find(assigned_id).update(item_order: index) if assigned_id.present?
    end
    render inline: ""
  end

  def destroy
    @sidebar = @sidebar.destroy
    flash[:notice] = t('camaleon_cms.admin.widgets.sidebar.error_deleted')
    redirect_to cama_admin_appearances_widgets_main_index_path
  end

  private

  def set_sidebar
    @sidebar = current_site.sidebars.find(params[:id])
  end

  def check_permission_role
    authorize! :manage, :widgets
  end

end
