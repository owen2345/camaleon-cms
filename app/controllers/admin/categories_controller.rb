class Admin::CategoriesController < AdminController

  before_action :set_post_type
  before_action :set_category, only: ['show','edit','update','destroy']

  def index
    @categories = @post_type.categories
    @categories = @categories.paginate(:page => params[:page], :per_page => current_site.admin_per_page)
    hooks_run("list_category", {categories: @categories, post_type: @post_type})
  end

  def show

  end

  def edit
    admin_breadcrumb_add("#{t('admin.button.edit')}")
  end

  def update
    if @category.update(params[:category])
      @category.set_options_from_form(params[:meta])
      @category.set_field_values(params[:field_options])
      flash[:notice] = t('admin.post_type.message.updated')
      redirect_to action: :index
    else
      render 'edit'
    end
  end


  def create
    data_term = params[:category]
    @category = @post_type.categories.new(data_term)
    if @category.save
      @category.set_options_from_form(params[:meta])
      @category.set_field_values(params[:field_options])
      flash[:notice] = t('admin.post_type.message.created')
      redirect_to action: :index
    else
      render 'edit'
    end
  end

  def destroy
    flash[:notice] = t('admin.post_type.message.deleted') if @category.destroy

    redirect_to action: :index
  end

  private


  def set_post_type
      @post_type = current_site.post_types.find_by_id(params[:post_type_id])
      authorize! :categories, @post_type
  end
  
  def set_category
      begin
        @category = Category.find_by_id(params[:id])
      rescue
        flash[:error] = t('admin.post_type.message.error')
        redirect_to admin_path
      end

  end

end
