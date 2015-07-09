class Admin::AppearancesController < AdminController

  #http_basic_authenticate_with name: "dhh", password: "secret", except: [:index, :show]

  def index
    redirect_to admin_dashboard_path
  end

end
