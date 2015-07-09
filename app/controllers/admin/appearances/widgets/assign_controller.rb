class Admin::Appearances::Widgets::AssignController < Admin::AppearancesController
  before_action :check_permission_role
  def new
    @sidebar = current_site.sidebars.find(params[:sidebar_id])
    @widget = current_site.widgets.find(params[:widget_id])
    @assigned = @sidebar.assigned.create!({title: "Default", widget_id: @widget.id})
    render partial: "form", locals: {assigned: @assigned, widget: @widget, sidebar: @sidebar}, layout: "admin/ajax"
  end

  def update
    @sidebar = current_site.sidebars.find(params[:sidebar_id])
    @assigned = @sidebar.assigned.find(params[:id])
    if @assigned.update(params[:assign])
      @assigned.set_field_values(params[:field_options])
      flash[:notice] = "Widget assign updated"
    else
      flash[:error] = "Widget assign not updated"
    end
    redirect_to admin_appearances_widgets_main_index_path
  end

  def destroy
    current_site.sidebars.find(params[:sidebar_id]).assigned.find(params[:id]).destroy
    render inline: ''
  end

  private
  def check_permission_role
    authorize! :manager, :widgets
  end

end