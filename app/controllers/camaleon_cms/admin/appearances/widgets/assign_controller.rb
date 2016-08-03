class CamaleonCms::Admin::Appearances::Widgets::AssignController < CamaleonCms::AdminController
  before_action :check_permission_role
  before_action :find_sidebar
  before_action :find_assigned_sidebar, only: [:update, :destroy]

  def new
    @widget = current_site.widgets.find(params[:widget_id])
    @assigned = @sidebar.assigned.create!({title: "Default", widget_id: @widget.id})
    render partial: "form", locals: {assigned: @assigned, widget: @widget, sidebar: @sidebar}, layout: "camaleon_cms/admin/ajax"
  end

  def update
    if @assigned.update(params.require(:assign).permit!)
      @assigned.set_field_values(params[:field_options])
      flash[:notice] = t('camaleon_cms.admin.widgets.assign.updated')
    else
      flash[:error] = t('camaleon_cms.admin.widgets.assign.error_updated')
    end
    redirect_to cama_admin_appearances_widgets_main_index_path
  end

  def destroy
    @assigned.destroy
    render inline: ''
  end

  private

  def find_sidebar
    @sidebar = current_site.sidebars.find(params[:sidebar_id])
  end

  def find_assigned_sidebar
    @assigned = @sidebar.assigned.find(params[:id])
  end

  def check_permission_role
    authorize! :manage, :widgets
  end

end
