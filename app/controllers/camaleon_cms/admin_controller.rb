class CamaleonCms::AdminController < CamaleonCms::CamaleonController
  rescue_from CanCan::AccessDenied do |exception|
    flash[:error] = "Error: #{exception.message}"
    redirect_to cama_admin_dashboard_path
  end
  include CamaleonCms::Admin::ApplicationHelper
  # layout 'camaleon_cms/admin'
  before_action :cama_authenticate
  before_action :admin_init_actions
  before_action :admin_logged_actions
  before_action :admin_before_hooks
  after_action :admin_after_hooks
  layout Proc.new { |controller| params[:cama_ajax_request].present? ? "camaleon_cms/admin/_ajax" : 'camaleon_cms/admin' }
  add_breadcrumb I18n.t("camaleon_cms.admin.sidebar.dashboard", default: 'Dashboard'), :cama_admin_path

  # render admin dashboard
  def index
    render "dashboard"
  end

  # ajax requests for admin panel
  # you need to send a param mode to control the action to to do
  def ajax
    case params[:mode]
      when "save_intro"
        current_site.set_option("save_intro", true);
      when "save_intro_post"
        current_site.set_option("save_intro_post", true);
    end
    render inline: ""
  end

  # render admin dashboard
  def dashboard
    index
  end

  # render search results
  # receive params[:q]
  # receive params[:kind]: define de type of the results type (content|category|tag) => default content
  # if this is receive a param[:ajax], then will render only results view
  def search
    add_breadcrumb I18n.t("camaleon_cms.admin.button.search")
    params[:kind] = "content" unless params[:kind].present?
    params[:q] = (params[:q] || '').downcase
    case params[:kind]
      when "post_type"
        @items = current_site.post_types.where("LOWER(#{Cama::PostType.table_name}.name) LIKE ? OR LOWER(#{Cama::PostType.table_name}.slug) LIKE ? OR LOWER(#{Cama::PostType.table_name}.description) LIKE ?", "%#{params[:q]}%", "%#{params[:q]}%", "%#{params[:q]}%")
      when "category"
        @items = current_site.full_categories.where("LOWER(#{Cama::Category.table_name}.name) LIKE ? OR LOWER(#{Cama::Category.table_name}.slug) LIKE ? OR LOWER(#{Cama::Category.table_name}.description) LIKE ?", "%#{params[:q]}%", "%#{params[:q]}%", "%#{params[:q]}%")
      when "tag"
        @items = current_site.post_tags.where("LOWER(#{Cama::PostTag.table_name}.name) LIKE ? OR LOWER(#{Cama::PostTag.table_name}.slug) LIKE ? OR LOWER(#{Cama::PostTag.table_name}.description) LIKE ?", "%#{params[:q]}%", "%#{params[:q]}%", "%#{params[:q]}%")
      else
        @items = current_site.posts.where("LOWER(#{Cama::Post.table_name}.title) LIKE ? OR LOWER(#{Cama::Post.table_name}.slug) LIKE ? OR LOWER(#{Cama::Post.table_name}.content_filtered) LIKE ?", "%#{params[:q]}%", "%#{params[:q]}%", "%#{params[:q]}%")
    end
    @items = @items.paginate(:page => params[:page], :per_page => current_site.admin_per_page)
  end

  private
  # initialize all vars and methods for admin panel
  def admin_init_actions
    I18n.locale = current_site.get_admin_language
    @_admin_menus = {}
    @_admin_breadcrumb = []
    @_extra_models_for_fields = []
    @cama_i18n_frontend = current_site.get_languages.first
  end

  # trigger hooks for admin panel before admin load
  def admin_before_hooks
    hooks_run("admin_before_load")
  end

  # trigger hooks for admin panel after admin load
  def admin_after_hooks
    hooks_run("admin_after_load")
  end

  def admin_logged_actions
    admin_menus_add_commons if !request.xhr? || !params[:cama_ajax_request].present? # initialize admin sidebar menus
  end
end
