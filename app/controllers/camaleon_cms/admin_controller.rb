module CamaleonCms
  class AdminController < CamaleonCms::CamaleonController
    rescue_from CanCan::AccessDenied do |exception|
      flash[:error] = "Error: #{exception.message}"
      redirect_to cama_admin_dashboard_path
    end
    # layout 'camaleon_cms/admin'
    before_action :cama_authenticate
    before_action :keep_request_attrs
    before_action :admin_init_actions
    before_action :enforce_password_change
    before_action :admin_logged_actions
    before_action :admin_before_hooks
    after_action :admin_after_hooks
    layout proc { |_controller|
             params[:cama_ajax_request].present? ? 'camaleon_cms/admin/_ajax' : 'camaleon_cms/admin'
           }
    add_breadcrumb I18n.t('camaleon_cms.admin.sidebar.dashboard', default: 'Dashboard'), :cama_admin_path
    helper_method :cama_get_i18n_frontend

    # render admin dashboard
    def index
      render 'dashboard'
    end

    # ajax requests for admin panel
    # you need to send a param mode to control the action to to do
    def ajax
      case params[:mode]
      when 'save_intro'
        current_site.set_option('save_intro', true)
      when 'save_intro_post'
        current_site.set_option('save_intro_post', true)
      end
      render plain: ''
    end

    # render admin dashboard
    def dashboard
      index
    end

    # render search results
    # receive params[:q]
    # receive params[:kind]: define de type of the results type (content|category|tag) => default content
    # if this is receiving a param[:ajax], then will render only results view
    def search
      add_breadcrumb I18n.t('camaleon_cms.admin.button.search')
      params[:kind] = 'content' if params[:kind].blank?
      params[:q] = (params[:q] || '').downcase
      table_name = case params[:kind]
                   when 'post_type'
                     base_query = current_site.post_types
                     Cama::PostType.table_name
                   when 'category'
                     base_query = current_site.full_categories
                     Cama::Category.table_name
                   when 'tag'
                     base_query = current_site.post_tags
                     Cama::PostTag.table_name
                   else
                     base_query = current_site.posts
                     Cama::Post.table_name
                   end
      @items = base_query.where(
        items_sql_by_name(table_name), "%#{params[:q]}%", "%#{params[:q]}%", "%#{params[:q]}%"
      )

      @items = @items.paginate(page: params[:page], per_page: current_site.admin_per_page)
    end

    # Decorators use this helper while rendering admin pages to keep public URLs in
    # the site's frontend language instead of the admin interface language.
    def cama_get_i18n_frontend
      @cama_i18n_frontend
    end

    private

    # Actions reachable while an administrator still owes a password change: the profile screen, its
    # submit, and the AJAX password-change endpoint. Everything else in the admin panel is redirected
    # to the change-password screen until the marker is cleared. Sign-out lives on SessionsController
    # (not an AdminController subclass), so it is out of this gate's reach and always reachable.
    PASSWORD_CHANGE_EXEMPT = { 'camaleon_cms/admin/users' => %w[profile profile_edit update updated_ajax] }.freeze

    # Force a newly provisioned administrator (minted with a generated password, see
    # harden-installer-default-admin) to set their own password before using the admin panel.
    def enforce_password_change
      return if cama_current_user.blank?
      return if cama_current_user.get_meta('must_change_password').blank?
      return if PASSWORD_CHANGE_EXEMPT[controller_path]&.include?(action_name)

      flash[:alert] = t('camaleon_cms.admin.users.message.must_change_password',
                        default: 'Please choose a new password before continuing.')
      redirect_to cama_admin_profile_edit_path
    end

    # initialize all vars and methods for admin panel
    def admin_init_actions
      I18n.locale = current_site.get_admin_language
      # Alias the legacy @_admin_menus ivar onto the live menu store so a hook using the WordPress-style
      # `@_admin_menus.delete('comments')` removal idiom mutates the same hash admin_menu_draw reads. The
      # menu-insert methods mutate in place (.replace), so this reference stays valid. Regression M19.
      @_admin_menus = CurrentRequest.admin_menu_items = {}
      @_admin_breadcrumb = []
      @_extra_models_for_fields = []
      # Cache the site's frontend language for decorators and plugins that still
      # need to distinguish admin requests from frontend visitor requests.
      @cama_i18n_frontend = current_site.get_languages.first
    end

    # trigger hooks for admin panel before admin load
    def admin_before_hooks
      run_hook_lifecycle('admin_before_load')
    end

    # Set cama_current_user and current_site in CurrentRequest so models can access the current context.
    # CurrentRequest is an ActiveSupport::CurrentAttributes subclass that auto-resets per request.
    def keep_request_attrs
      CurrentRequest.user = cama_current_user
      CurrentRequest.site = current_site
    end

    # trigger hooks for admin panel after admin load
    def admin_after_hooks
      run_hook_lifecycle('admin_after_load')
    end

    def admin_logged_actions
      admin_menus_add_commons if !request.xhr? || params[:cama_ajax_request].blank? # initialize admin sidebar menus
    end

    def items_sql_by_name(table_name)
      lower_name = "LOWER(#{table_name}"
      if table_name == Cama::Post.table_name
        return "#{lower_name}.title) LIKE ? OR #{lower_name}.slug) LIKE ? OR #{lower_name}.content_filtered) LIKE ?"
      end

      "#{lower_name}.name) LIKE ? OR #{lower_name}.slug) LIKE ? OR #{lower_name}.description) LIKE ?"
    end
  end
end
