class CamaleonCms::Admin::CommentsController < CamaleonCms::AdminController
  include CamaleonCms::CommentHelper
  add_breadcrumb I18n.t("camaleon_cms.admin.sidebar.comments"), :cama_admin_comments_url
  before_action :validate_role
  before_action :set_post, except: :list
  before_action :set_comment, except: [:list, :index, :new, :create]
  def list
    @posts = current_site.posts.no_trash.joins(:comments).select("#{CamaleonCms::Post.table_name}.*, #{CamaleonCms::PostComment.table_name}.post_id").uniq.paginate(:page => params[:page], :per_page => current_site.admin_per_page)
  end

  # list of post comments for current post
  def index
    @comments = @post.comments.main.paginate(:page => params[:page], :per_page => current_site.admin_per_page)
  end

  def edit
    render 'form', layout: false
  end

  # render a form to register a new comment
  def answer
    @answer = @comment.children.new
    render 'form_answer', layout: false
  end

  # save a new anwer for this comment
  def save_answer
    answer = @comment.children.create(cama_comments_get_common_data.merge({post_id: @post.id, content: params[:comment][:content]}))
    flash[:notice] = t('camaleon_cms.admin.comments.message.responses')
    redirect_to action: :index
  end

  # toggle status of a comment
  def toggle_status
    _s = {a: "approved", s: "spam", p: "pending"}
    k = _s[params[:s].to_sym]
    @comment.update(approved: k)
    flash[:notice] = "#{t('camaleon_cms.admin.comments.message.change_status')} #{t("camaleon_cms.admin.comments.message.#{k}")}"
    redirect_to action: :index
  end

  def update
    if @comment.update(content: params[:comment][:content])
      flash[:notice] = t('camaleon_cms.admin.comments.message.updated')
      redirect_to action: :index
    else
      render 'form'
    end
  end

  def new
    @comment = @post.comments.new
    render 'form', layout: false
  end

  def create
    comment = @post.comments.create(cama_comments_get_common_data.merge({post_id: @post.id, content: params[:comment][:content]}))
    flash[:notice] = t('camaleon_cms.admin.comments.message.responses')
    redirect_to action: :index
  end

  def destroy
    flash[:notice] = t('camaleon_cms.admin.comments.message.destroy') if @comment.destroy
    redirect_to action: :index
  end


  private
  # define the parent post
  def set_post
    @post = current_site.posts.find(params[:post_id]).decorate
    add_breadcrumb I18n.t("camaleon_cms.admin.table.post")
    add_breadcrumb @post.the_title, @post.the_edit_url
  end

  # define the parent or current comment
  def set_comment
    begin
      @comment = @post.comments.find(params[:id] || params[:comment_id])
    rescue
      flash[:error] = t('camaleon_cms.admin.comments.message.error')
      redirect_to cama_admin_path
    end
  end

  def validate_role
    authorize! :manage, :comments
  end
end
