class CamaleonCms::Admin::UsersController < CamaleonCms::AdminController
  before_action :validate_role, except: [:profile, :profile_edit]
  add_breadcrumb I18n.t("camaleon_cms.admin.sidebar.users"), :cama_admin_users_url
  before_action :set_user, only: [:show, :edit, :update, :destroy, :impersonate]

  def index
    add_breadcrumb I18n.t("camaleon_cms.admin.users.list_users")
    @users = current_site.users.paginate(:page => params[:page], :per_page => current_site.admin_per_page)
  end

  def profile
    add_breadcrumb I18n.t("camaleon_cms.admin.users.profile")
    @user = params[:user_id].present? ? current_site.the_user(params[:user_id].to_i).object : cama_current_user.object
    return edit
  end

  def profile_edit
    add_breadcrumb I18n.t("camaleon_cms.admin.users.profile")
    @user = cama_current_user.object
    return edit
  end

  def show
    add_breadcrumb I18n.t("camaleon_cms.admin.users.profile")
    render 'profile'
  end

  def update
    r={user: @user}; hooks_run('user_update', r)
    if @user.update(params.require(:user).permit!)
      @user.set_metas(params[:meta]) if params[:meta].present?
      @user.set_field_values(params[:field_options])
      r = {user: @user, message: t('camaleon_cms.admin.users.message.updated'), params: params}; hooks_run('user_after_edited', r)
      flash[:notice] = r[:message]
      r={user: @user}; hooks_run('user_updated', r)
      if cama_current_user.id == @user.id
        redirect_to action: :profile_edit
      else
        redirect_to action: :index
      end
    else
      render 'form'
    end
  end

  # update som ajax requests from profile or user form
  def updated_ajax
    @user = current_site.users.find(params[:user_id])
    render inline: @user.update(params.require(:password).permit!) ? "" : @user.errors.full_messages.join(', ')
  end

  def edit
    add_breadcrumb I18n.t("camaleon_cms.admin.button.edit")
    r = {user: @user, render: 'form' }
    hooks_run('user_edit', r)
    render r[:render]
  end

  def new
    @user ||= current_site.users.new
    add_breadcrumb I18n.t("camaleon_cms.admin.button.new")
    r = {user: @user, render: 'form' }
    hooks_run('user_new', r)
    render r[:render]
  end

  def create
    user_data = params.require(:user).permit!
    @user = current_site.users.new(user_data)
    r={user: @user}; hooks_run('user_create', r)
    if @user.save
      @user.set_metas(params[:meta]) if params[:meta].present?
      @user.set_field_values(params[:field_options])
      r={user: @user}; hooks_run('user_created', r)
      flash[:notice] = t('camaleon_cms.admin.users.message.created')
      redirect_to action: :index
    else
      new
    end
  end

  def destroy
    if @user.destroy
      flash[:notice] = t('camaleon_cms.admin.users.message.deleted')
      r={user: @user}; hooks_run('user_destroyed', r)
    end
    redirect_to action: :index
  end

  def impersonate
    authorize! :impersonate, @user
    session_switch_user(@user, cama_admin_dashboard_path)
  end

  private

  def validate_role
    (user_id_param.present? && cama_current_user.id.to_s == user_id_param) || authorize!(:manage, :users)
  end

  def user_id_param
    user_params = params[:id] || params[:user_id]
  end

  def set_user
    begin
      @user = current_site.users.find(user_id_param)
    rescue
      flash[:error] = t('camaleon_cms.admin.users.message.error')
      redirect_to cama_admin_path
    end
  end
end
