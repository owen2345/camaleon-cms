class Admin::Appearances::Widgets::SidebarController < Admin::AppearancesController
  before_action :check_permission_role

  def new
    @sidebar ||= current_site.sidebars.new
    render 'form', layout: false
  end

  def create
    @sidebar = current_site.sidebars.new(params[:widget_sidebar])
    if @sidebar.save
      flash[:notice] = "Sidebar Create"
    else
      flash[:error] = "No created sidebar"
    end
    redirect_to admin_appearances_widgets_main_index_path
  end

  def edit
    @sidebar = current_site.sidebars.find(params[:id])
    new
  end

  def update
    if current_site.sidebars.find(params[:id]).update(params[:widget_sidebar])
      flash[:notice] = "Sidebar Update"
    else
      flash[:error] = "No  Update sidebar"
    end
    redirect_to admin_appearances_widgets_main_index_path
  end

  def reorder
    params[:pos].each_with_index do |assigned_id, index|
      current_site.sidebars.find(params[:sidebar_id]).assigned.find(assigned_id).update(item_order: index) if assigned_id.present?
    end
    render inline: ""
  end

  def destroy
    @sidebar = current_site.sidebars.find(params[:id]).destroy
    flash[:notice] = "Sidebar deleted."
    redirect_to admin_appearances_widgets_main_index_path
  end

  private
  def check_permission_role
    authorize! :manager, :widgets
  end

end
