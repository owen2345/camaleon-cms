module CamaleonCms
  module Admin
    class UsersController < CamaleonCms::AdminController
      include CamaleonCms::Admin::CustomFieldsConcern

      before_action :validate_role, except: %i[profile profile_edit]

      add_breadcrumb I18n.t('camaleon_cms.admin.sidebar.users'), :cama_admin_users_url

      before_action :set_user, only: %i[show edit update destroy impersonate]

      def index
        add_breadcrumb I18n.t('camaleon_cms.admin.users.list_users')
        @users = current_site.users.paginate(page: params[:page], per_page: current_site.admin_per_page)
      end

      def profile
        add_breadcrumb I18n.t('camaleon_cms.admin.users.profile')
        user_id = params[:user_id]
        # Authorize from the parameter before loading, so a denied caller cannot tell
        # whether the requested user exists from the shape of the response.
        authorize! :manage, :users if user_id.present? && user_id.to_i != cama_current_user.id
        @user = user_id.present? ? current_site.the_user(user_id.to_i)&.object : cama_current_user.object
        if @user.blank?
          flash[:error] = t('camaleon_cms.admin.users.message.error')
          return redirect_to(cama_admin_path)
        end

        edit
      end

      def profile_edit
        add_breadcrumb I18n.t('camaleon_cms.admin.users.profile')
        @user = cama_current_user.object
        edit
      end

      def show
        add_breadcrumb I18n.t('camaleon_cms.admin.users.profile')
        render 'profile'
      end

      def update
        r = { user: @user }
        hooks_run('user_update', r)
        if @user.update(user_params)
          @user.set_metas(user_meta_params) if params[:meta].present?
          @user.set_field_values(cama_permitted_field_options(user_field_scope)) if params[:field_options].present?
          r = { user: @user, message: t('camaleon_cms.admin.users.message.updated'), params: params }
          hooks_run('user_after_edited', r)
          flash[:notice] = r[:message]
          r = { user: @user }
          hooks_run('user_updated', r)
          if cama_current_user.id == @user.id
            redirect_to action: :profile_edit
          else
            redirect_to action: :index
          end
        else
          render 'form'
        end
      end

      # update some ajax requests from profile or user form
      def updated_ajax
        @user = current_site.users.find(user_id_param)
        update_session = current_user_is?(@user)
        attrs = params.require(:password).permit(%i[password password_confirmation])
        @user.update(password: attrs.require(:password), password_confirmation: attrs.require(:password_confirmation))

        return render plain: @user.errors.full_messages.join(', '), status: :unprocessable_entity if @user.errors.any?

        # A newly provisioned admin (see harden-installer-default-admin) owes a password change; clearing
        # the marker on a real change lets them past the enforce_password_change gate.
        @user.delete_meta('must_change_password') if @user.saved_change_to_password_digest?

        # keep user logged in when changing their own password
        update_auth_token_in_cookie @user.auth_token if update_session && @user.saved_change_to_password_digest?
      rescue ActiveRecord::RecordNotFound
        # The other failure paths of this action answer with a status and a short text body, so an
        # unresolvable target does too rather than falling through to the framework's HTML error
        # page. Catch this class only, never StandardError, so a genuine lookup failure still
        # surfaces instead of being reported as a missing user.
        render plain: t('camaleon_cms.admin.users.message.error'), status: :not_found
      rescue ActionController::ParameterMissing => e
        render plain: "ERROR: #{e.class.name}, #{e.message}", status: :bad_request
      end

      def update_auth_token_in_cookie(token)
        return unless cookie_auth_token_complete?

        current_token = cookie_split_auth_token
        updated_token = [token, *current_token[1..]]
        cookies[:auth_token] = updated_token.join('&')
      end

      def current_user_is?(user)
        user_auth_token_from_cookie == user.auth_token
      rescue StandardError
        false
      end

      def edit
        add_breadcrumb I18n.t('camaleon_cms.admin.button.edit')
        r = { user: @user, render: 'form' }
        hooks_run('user_edit', r)
        render r[:render]
      end

      def new
        @user ||= current_site.users.new
        add_breadcrumb I18n.t('camaleon_cms.admin.button.new')
        r = { user: @user, render: 'form' }
        hooks_run('user_new', r)
        render r[:render]
      end

      def create
        @user = current_site.users.new(user_params)
        r = { user: @user }
        hooks_run('user_create', r)
        if @user.save
          @user.set_metas(user_meta_params) if params[:meta].present?
          @user.set_field_values(cama_permitted_field_options(user_field_scope)) if params[:field_options].present?
          r = { user: @user }
          hooks_run('user_created', r)
          flash[:notice] = t('camaleon_cms.admin.users.message.created')
          redirect_to action: :index
        else
          new
        end
      end

      def destroy
        if cama_current_user.id == @user.id
          flash[:error] =
            t('camaleon_cms.admin.users.message.user_can_not_delete_own_account',
              default: 'User can not delete own account')
        elsif @user.destroy
          flash[:notice] = t('camaleon_cms.admin.users.message.deleted')
          r = { user: @user }
          hooks_run('user_destroyed', r)
        end
        redirect_to action: :index
      end

      def impersonate
        authorize! :impersonate, @user
        session_switch_user(@user, cama_admin_dashboard_path)
      end

      private

      def validate_role
        user_id = user_id_param
        (user_id.present? && cama_current_user.id.to_s == user_id.to_s) || authorize!(:manage, :users)
      end

      # Only a scalar user_id participates in target resolution (?user_id[]= would
      # crash the record lookup and flip authorization); otherwise the route id wins
      def user_id_param
        user_id = params[:user_id]
        return params[:id] unless user_id.is_a?(String)

        user_id
      end

      def user_params
        p = params.require(:user).permit(:username, :email, :first_name, :last_name, :password, :password_confirmation)
        p[:role] = params[:user][:role] if cama_current_user.role_grantor?(@user) && params[:user][:role].present?
        p
      end

      def user_meta_params
        params.require(:meta).permit(:avatar, :slogan)
      end

      # Allowed field slugs must be keyed on the demodulized placement name the settings form
      # emits and get_user_field_groups queries; keyed on a hardcoded 'User' the lookup finds no
      # groups for a host user model that demodulizes to another name, discarding every value.
      def user_field_scope
        PluginRoutes.get_user_class_name.demodulize
      end

      def set_user
        @user = current_site.users.find(user_id_param)
      rescue StandardError
        flash[:error] = t('camaleon_cms.admin.users.message.error')
        redirect_to cama_admin_path
      end
    end
  end
end
