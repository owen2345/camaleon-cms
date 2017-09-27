class CamaleonCms::Admin::PostsController < CamaleonCms::AdminController
  add_breadcrumb I18n.t("camaleon_cms.admin.sidebar.contents")
  before_action :set_post_type, :except => [:ajax]
  before_action :set_post, only: ['show','edit','update','destroy']
  skip_before_action :admin_logged_actions, only: [:trash, :restore, :destroy, :ajax], raise: false
  skip_before_action :verify_authenticity_token, only: [:ajax], raise: false

  def index
    authorize! :posts, @post_type
    per_page = current_site.admin_per_page
    posts_all = @post_type.posts.eager_load(:parent, :post_type)
    if params[:taxonomy].present? && params[:taxonomy_id].present?
      if params[:taxonomy] == "category"
        cat_owner = current_site.full_categories.find(params[:taxonomy_id]).decorate
        posts_all = cat_owner.posts
        add_breadcrumb t("camaleon_cms.admin.post_type.category"), @post_type.the_admin_url("category")
        add_breadcrumb cat_owner.the_title, cat_owner.the_edit_url
      end

      if params[:taxonomy] == "post_tag"
        tag_owner = current_site.post_tags.find(params[:taxonomy_id]).decorate
        posts_all = tag_owner.posts
        add_breadcrumb t("camaleon_cms.admin.post_type.tags"), @post_type.the_admin_url("tag")
        add_breadcrumb tag_owner.the_title, tag_owner.the_edit_url
      end
    end

    if params[:q].present?
      params[:q] = (params[:q] || '').downcase
      posts_all = posts_all.where("LOWER(#{CamaleonCms::Post.table_name}.title) LIKE ?", "%#{params[:q]}%")
    end
    
    posts_all = posts_all.where(user_id: current_user) if cannot?(:edit_other, @post_type) # filter only own contents 
    
    @posts = posts_all
    params[:s] = 'published' unless params[:s].present?
    @lists_tab = params[:s]
    add_breadcrumb I18n.t("camaleon_cms.admin.post_type.#{params[:s]}") if params[:s].present?
    case params[:s]
      when "published", "pending", "trash"
        @posts = @posts.send(params[:s])
      when "draft"
        @posts = @posts.drafts
      when "all"
        @posts = @posts.no_trash
    end

    @btns = {published: "#{t('camaleon_cms.admin.post_type.published')} (#{posts_all.published.size})", all: "#{t('camaleon_cms.admin.post_type.all')} (#{posts_all.no_trash.size})", pending: "#{t('camaleon_cms.admin.post_type.pending')} (#{posts_all.pending.size})", draft: "#{t('camaleon_cms.admin.post_type.draft')} (#{posts_all.drafts.size})", trash: "#{t('camaleon_cms.admin.post_type.trash')} (#{posts_all.trash.size})"}
    per_page = 9999999 if @post_type.manage_hierarchy?
    r = {posts: @posts, post_type: @post_type, btns: @btns, all_posts: posts_all, render: 'index', per_page: per_page }
    hooks_run("list_post", r)
    @posts = r[:posts].paginate(:page => params[:page], :per_page => r[:per_page])
    render r[:render]
  end

  def show
  end

  def new
    add_breadcrumb I18n.t("camaleon_cms.admin.button.new")
    authorize! :create_post, @post_type
    @post_form_extra_settings = []
    @post ||= @post_type.posts.new
    r = {post: @post, post_type: @post_type, extra_settings: @post_form_extra_settings, render: "form"}; hooks_run("new_post", r)
    render r[:render]
  end

  def create
    authorize! :create_post, @post_type
    post_data = get_post_data(true)
    CamaleonCms::Post.drafts.find(post_data[:draft_id]).destroy rescue nil
    @post = @post_type.posts.new(post_data)
    r = {post: @post, post_type: @post_type}; hooks_run("create_post", r)
    @post = r[:post]
    if @post.save
      @post.set_metas(params[:meta])
      @post.set_field_values(params[:field_options])
      @post.set_options(params[:options])
      flash[:notice] = t('camaleon_cms.admin.post.message.created', post_type: @post_type.decorate.the_title)
      r = {post: @post, post_type: @post_type}; hooks_run("created_post", r)
      redirect_to action: :edit, id: @post.id
    else
      # render 'form'
      new
    end
  end

  def edit
    add_breadcrumb I18n.t("camaleon_cms.admin.button.edit")
    authorize! :update, @post
    @post_form_extra_settings = []
    r = {post: @post, post_type: @post_type, extra_settings: @post_form_extra_settings, render: "form"}; hooks_run("edit_post", r)
    render r[:render]
  end

  def update
    post_data = get_post_data
    delete_drafts = false
    if @post.draft_child? && @post.parent.present?
      # This is a draft (as a child of the original post)
      original_parent = @post.parent.parent
      post_data[:post_parent] = original_parent.present? ? original_parent.id : nil
      @post = @post.parent
      delete_drafts = true
    elsif @post.draft?
      # This is a normal draft (post whose status was set to 'draft')
      @post.status = 'published' if post_data[:status].blank?
    end
    authorize! :update, @post
    r = {post: @post, post_type: @post_type}; hooks_run("update_post", r)
    @post = r[:post]
    if @post.update(post_data)
      # delete drafts only on successful update operation
      @post.drafts.destroy_all if delete_drafts
      @post.set_metas(params[:meta])
      @post.set_field_values(params[:field_options])
      @post.set_options(params[:options])
      hooks_run("updated_post", {post: @post, post_type: @post_type})
      flash[:notice] = t('camaleon_cms.admin.post.message.updated', post_type: @post_type.decorate.the_title)
      redirect_to action: :edit, id: @post.id
    else
      edit
    end
  end

  def trash
    @post = @post_type.posts.find(params[:post_id])
    authorize! :destroy, @post
    @post.set_option('status_default', @post.status)
    # @post.children.destroy_all unless @post.draft? TODO: why delete children?
    @post.update_column('status', 'trash')
    @post.update_extra_data
    hooks_run("trashed_post", {post: @post, post_type: @post_type})
    flash[:notice] = t('camaleon_cms.admin.post.message.trash', post_type: @post_type.decorate.the_title)
    redirect_to action: :index, s: params[:s]
  end

  def restore
    @post = @post_type.posts.find(params[:post_id])
    authorize! :update, @post
    @post.update_column('status', @post.options[:status_default] || 'pending')
    @post.update_extra_data
    hooks_run("restored_post", {post: @post, post_type: @post_type})
    flash[:notice] = t('camaleon_cms.admin.post.message.restore', post_type: @post_type.decorate.the_title)
    redirect_to action: :index, s: params[:s]
  end

  def destroy
    authorize! :destroy, @post
    r = {post: @post, post_type: @post_type, flag: true}
    hooks_run("destroy_post", r)
    if r[:flag]
      if @post.destroy
        hooks_run("destroyed_post", {post: @post, post_type: @post_type})
        flash[:notice] = t('camaleon_cms.admin.post.message.deleted', post_type: @post_type.decorate.the_title)
        return redirect_to action: :index, s: params[:s]
      else
        flash[:error] = @post.errors.full_messages.join(', ')
      end
    end
    redirect_to(request.referer || url_for(action: :index, s: params[:s]))
  end

  # ajax options
  def ajax
    json = {error: 'Not Found'}
    case params[:method]
      when 'exist_slug'
        slug = current_site.get_valid_post_slug(params[:slug].to_s, params[:post_id])
        json = {slug: slug, index: 1}
    end
    render json: json
  end

  private
  # define post type parent
  def set_post_type
    @post_type = current_site.post_types.find_by_id(params[:post_type_id] )
    unless @post_type.present?
      flash[:error] =  t('camaleon_cms.admin.request_error_message')
      redirect_to cama_admin_path
      return
    end
    @post_type = @post_type.decorate
    add_breadcrumb @post_type.the_title, @post_type.the_admin_url
  end

  def set_post
    begin
      @post = @post_type.posts.find(params[:id])
      @post_decorate = @post.decorate
    rescue
      flash[:error] =  t('camaleon_cms.admin.post.message.error', post_type: @post_type.decorate.the_title)
      redirect_to cama_admin_path
    end
  end

  # return common params data for posts
  # is_create: indicate if this info is for create a new post
  def get_post_data(is_create = false)
    post_data = params.require(:post).permit!
    post_data[:user_id] = cama_current_user.id if is_create
    post_data[:status] = 'pending' if post_data[:status] == 'published' && cannot?(:publish_post, @post_type)
    post_data[:data_tags] = params[:tags].to_s
    post_data[:data_categories] = params[:categories] || []
    post_data
  end
end
