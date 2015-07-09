class Admin::Posts::DraftsController < Admin::PostsController

  #skip_before_filter :admin_init_settings

  def index
    render json: @post_type
  end

  def create
    post_data = get_params_data
    post_data[:data_tags] = params[:tags].to_s
    post_data[:data_categories] = params[:categories] || []
    if params[:post_id].present?
      @post_draft = Post.drafts.where(post_parent: params[:post_id]).first
      @post_draft.attributes = post_data if @post_draft.present?
    end
    @post_draft = @post_type.posts.new(post_data) unless @post_draft.present?
    r = {post: @post_draft, post_type: ""}; hooks_run("create_post", r)
    if @post_draft.save(:validate => false)
      @post_draft.set_meta_from_form(params[:meta])
      @post_draft.set_field_values(params[:field_options])
      @post_draft.set_option("keywords", post_data[:keywords])
      msg = {draft: {id: @post_draft.id}, _drafts_path: admin_post_type_draft_path(@post_type.id, @post_draft)}
      r = {post: @post_draft, post_type: ""}; hooks_run("created_post", r)
    else
      msg = {error: @post_draft.errors.full_messages}
    end

    render json: msg
  end


  def update
    post_data = get_params_data
    post_data[:data_tags] = params[:tags].to_s
    post_data[:data_categories] = params[:categories] || []
    @post_draft = Post.drafts.find(params[:id])
    @post_draft.attributes = post_data
    r = {post: @post_draft, post_type: ""}; hooks_run("update_post", r)
    if @post_draft.save(validate: false)
      @post_draft.set_meta_from_form(params[:meta])
      @post_draft.set_field_values(params[:field_options])
      @post_draft.set_option("keywords", post_data[:keywords])
      hooks_run("updated_post", {post: @post_draft, post_type: ""})
      msg = {draft: {id: @post_draft.id}}
    else
      msg = {error: @post_draft.errors.full_messages}
    end
    render json: msg
  end


  def destroy

  end

  private
  def get_params_data
    post_data = params[:post]
    post_data[:status] = 'draft'
    post_data[:comment_count] = 0
    post_data[:post_parent] = params[:post_id]
    post_data[:user_id] = current_user.id unless post_data[:user_id].present?
    post_data
  end


end
