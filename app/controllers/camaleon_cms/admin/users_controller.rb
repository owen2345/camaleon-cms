module CamaleonCms
  module Admin
    class UsersController < CamaleonCms::AdminController
      include CamaleonCms::Admin::CustomFieldsConcern

      # Member actions resolve a single target user, so a caller acting on their own record is
      # legitimately exempt from :manage, :users. The collection actions (index/new/create) resolve
      # no such target, so a self-referential ?user_id= must not exempt them from the capability check.
      SELF_TARGET_ACTIONS = %w[show edit update destroy impersonate updated_ajax].freeze

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
        # Only an admin may reset an admin's password; a `:manage, :users` holder who could would sign in
        # as that admin (H10). Self-service and non-admin targets are unaffected.
        unless cama_current_user.may_edit_credentials?(@user)
          return render plain: t('camaleon_cms.admin.users.message.error'), status: :forbidden
        end

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
        # Route through the shared hardened-cookie options (audit M3/M4): a bare assignment here
        # re-issued the auth cookie without HttpOnly/Secure/domain/expiry when a user changed their
        # own password, undoing the M3 hardening for that session.
        cookies[:auth_token] = cama_auth_cookie_options(updated_token.join('&'))
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
        return if self_target_own_record?

        authorize! :manage, :users
      end

      # The self-exemption applies only to member actions that resolve a single target user; a
      # collection action (index/new/create) has no such target, so a self-referential ?user_id=
      # never exempts it (audit finding H7).
      def self_target_own_record?
        return false unless SELF_TARGET_ACTIONS.include?(action_name)

        user_id = user_id_param
        user_id.present? && cama_current_user.id.to_s == user_id.to_s
      end

      # Only a scalar user_id participates in target resolution (?user_id[]= would
      # crash the record lookup and flip authorization); otherwise the route id wins
      def user_id_param
        user_id = params[:user_id]
        return params[:id] unless user_id.is_a?(String)

        user_id
      end

      def user_params
        fields = %i[username email first_name last_name password password_confirmation]
        # Only an admin may change an admin's password or recovery identifiers (email/username); drop them
        # for anyone else editing an admin, the same fail-safe the role permit below uses (H10).
        unless cama_current_user.may_edit_credentials?(@user)
          fields -= %i[username email password password_confirmation]
        end
        p = params.require(:user).permit(*fields)
        # role is a scalar slug; coerce anything else (e.g. a nested user[role][x] param) to nil so it is
        # never mass-assigned — assigning an unpermitted nested Parameters would raise and 500 the request.
        requested_role = params[:user][:role]
        requested_role = nil unless requested_role.is_a?(String)
        p[:role] = requested_role if requested_role.present? && cama_current_user.role_grantor?(@user, requested_role)
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
