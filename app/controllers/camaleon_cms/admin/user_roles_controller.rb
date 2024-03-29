module CamaleonCms
  module Admin
    class UserRolesController < CamaleonCms::AdminController
      before_action :validate_role
      add_breadcrumb I18n.t('camaleon_cms.admin.sidebar.users'), :cama_admin_users_url
      add_breadcrumb I18n.t('camaleon_cms.admin.users.user_roles'), :cama_admin_user_roles_path
      before_action :set_user_roles, only: %w[show edit update destroy]

      def index
        @user_roles = current_site.user_roles
        @user_roles = @user_roles.paginate(page: params[:page], per_page: current_site.admin_per_page)
      end

      def show; end

      def new
        add_breadcrumb I18n.t('camaleon_cms.admin.button.new')
        @user_role ||= current_site.user_roles.new
        render 'form'
      end

      def create
        user_role_data = params.require(:user_role).permit!
        @user_role = current_site.user_roles.new(user_role_data)
        if @user_role.save
          @user_role.set_meta("_post_type_#{current_site.id}",
                              defined?(params[:rol_values][:post_type]) ? params[:rol_values][:post_type] : {})
          @user_role.set_meta("_manager_#{current_site.id}",
                              defined?(params[:rol_values][:post_type]) ? params[:rol_values][:manager] : {})
          flash[:notice] = t('camaleon_cms.admin.users.message.rol_created')
          redirect_to action: :edit, id: @user_role.id
        else
          new
        end
      end

      def edit
        add_breadcrumb I18n.t('camaleon_cms.admin.button.edit')
        render 'form'
      end

      def update
        if @user_role.update(params.require(:user_role).permit!)
          if @user_role.editable?
            @user_role.set_meta("_post_type_#{current_site.id}",
                                defined?(params[:rol_values][:post_type]) ? params[:rol_values][:post_type] : {})
            @user_role.set_meta("_manager_#{current_site.id}",
                                defined?(params[:rol_values][:post_type]) ? params[:rol_values][:manager] : {})
          end
          flash[:notice] = t('camaleon_cms.admin.users.message.rol_updated')
          redirect_to action: :edit, id: @user_role.id
        else
          edit
        end
      end

      def destroy
        if @user_role.editable? && @user_role.destroy
          flash[:notice] = t('camaleon_cms.admin.users.message.rol_deleted')
        else
          flash[:error] =
            t('camaleon_cms.admin.users.message.role_can_not_be_deleted', default: 'This role can not be deleted')
        end
        redirect_to action: :index
      end

      private

      def validate_role
        authorize! :manage, :users
      end

      def set_user_roles
        @user_role = current_site.user_roles.find(params[:id]).decorate
      rescue StandardError
        flash[:error] = t('camaleon_cms.admin.users.message.rol_error')
        redirect_to action: :index
      end
    end
  end
end
