module CamaleonCms
  class AdminController < CamaleonCms::CamaleonController
    rescue_from CanCan::AccessDenied do |exception|
      flash[:error] = "Error: #{exception.message}"
      redirect_to cama_admin_dashboard_path
    end
    # Security (scan-and-reject policy, audit M17): custom-field values save after their parent
    # through `custom_field_values.create!`, so a value the gate refuses arrives here as
    # RecordInvalid. Surface the refusal as a flash error naming the field instead of a 500; the
    # parent's own attributes were already saved, only the refused value rows are rolled back.
    rescue_from ActiveRecord::RecordInvalid do |exception|
      raise exception unless exception.record.is_a?(CamaleonCms::CustomFieldsRelationship)

      flash[:error] = exception.record.errors.full_messages.to_sentence
      redirect_back fallback_location: cama_admin_dashboard_path
    end
    # layout 'camaleon_cms/admin'
    # Admin responses are user-specific and must never be served from a browser or shared cache;
    # without this a stale render (e.g. an editor that failed to initialize on a cold boot) can
    # reappear after a restart until a manual reload. Set first so it applies to auth redirects too.
    before_action :cama_prevent_response_caching
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
      # A crafted ?q[]=x / ?q[a]=b arrives as an Array / Parameters, which has no #downcase; treat any
      # non-String q as an empty query instead of 500ing.
      params[:q] = params[:q].is_a?(String) ? params[:q].downcase : ''
      # Security (audit 2026-08-11 M12): the action had no authorization and no status filter, so any
      # admin-area user (e.g. a client with no content rights) could enumerate every post title/slug in
      # every status -- draft, pending, private, trash -- plus post types, categories and tags they
      # cannot access. Scope every kind to the post types the caller may manage: content and post types
      # by :posts, categories and tags by their own :categories / :post_tags abilities (the roles UI
      # grants manage_categories / manage_tags independently of any post edit right).
      table_name = case params[:kind]
                   when 'post_type'
                     base_query = current_site.post_types.where(id: cama_admin_searchable_post_type_ids)
                     Cama::PostType.table_name
                   when 'category'
                     pt_ids = cama_admin_searchable_post_type_ids(:categories)
                     # A category's post type lives in post_type_id (the status column) at every nesting
                     # level; parent_id points at the parent *category* for children, so filtering by it
                     # would drop every nested category.
                     base_query = current_site.full_categories.where(post_type_id: pt_ids)
                     Cama::Category.table_name
                   when 'tag'
                     pt_ids = cama_admin_searchable_post_type_ids(:post_tags)
                     base_query = current_site.post_tags.where(parent_id: pt_ids)
                     Cama::PostTag.table_name
                   else
                     base_query = cama_admin_searchable_posts
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

    # Send `Cache-Control: no-store` on every admin response so no admin page is ever cached by the
    # browser or an intermediary. Admin pages are per-user and dynamic; caching them risks a stale
    # render being reused (the cold-boot blank-editor symptom is one such case).
    def cama_prevent_response_caching
      response.headers['Cache-Control'] = 'no-store'
    end

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

    # Post types on which the caller holds `action`: :posts for content and the post-type kind,
    # :categories / :post_tags for the taxonomy kinds. Admins hold every ability on every type, so
    # skip the per-record sweep (and the redundant IN filter it would feed) for them.
    def cama_admin_searchable_post_type_ids(action = :posts)
      return current_site.post_types.ids if can?(:manage, :all)

      cama_admin_searchable_post_types(action).map(&:id)
    end

    def cama_admin_searchable_post_types(action)
      current_site.post_types.select { |pt| can?(action, pt) }
    end

    # Posts the caller may see in admin search: the accessible post types narrowed by the shared
    # admin visibility rule. edit_other implies :posts, so the visibility sweep only rechecks the
    # already-loaded listable subset; admins skip the scoping entirely.
    def cama_admin_searchable_posts
      return current_site.posts if can?(:manage, :all)

      listable = cama_admin_searchable_post_types(:posts)
      cama_admin_visible_posts(current_site.posts.where(post_type_id: listable.map(&:id)), listable)
    end

    # Restrict `scope` to the posts the caller may see in admin listings across `post_types`: every
    # post on the types where they hold edit_other, only their own elsewhere. Admins see everything.
    # Single source of the visibility rule for PostsController#index (per post type) and admin search
    # (across types) -- these drifting apart is how the M12 disclosure shipped, so change it here, not
    # at a call site.
    def cama_admin_visible_posts(scope, post_types)
      return scope if can?(:manage, :all)

      edit_other_ids = post_types.select { |pt| can?(:edit_other, pt) }.map(&:id)
      return scope if edit_other_ids.length == post_types.length

      scope.where(post_type_id: edit_other_ids).or(scope.where(user_id: cama_current_user.id))
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
