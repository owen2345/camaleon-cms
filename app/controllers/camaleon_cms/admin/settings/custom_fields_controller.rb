class CamaleonCms::Admin::Settings::CustomFieldsController < CamaleonCms::Admin::SettingsController
  add_breadcrumb I18n.t("camaleon_cms.admin.sidebar.custom_fields"), :cama_admin_settings_custom_fields_path
  before_action :set_custom_field_group, only: [:show,:edit,:update,:destroy]

  def index
    @field_groups = current_site.field_groups
    @field_groups = @field_groups.where(object_class: params[:c]) if params[:c].present?
    @field_groups = @field_groups.where(objectid: params[:id]) if params[:id].present?
    @field_groups = @field_groups.paginate(page: params[:page], per_page: current_site.admin_per_page)
  end

  def get_items
    @key = params[:key]
    render partial: "get_items", layout: false
  end

  def show
  end

  def edit
    add_breadcrumb I18n.t("camaleon_cms.admin.button.edit")
    render 'form'
  end

  def update
    if @field_group.update(group_params)
      flash[:notice] = t('camaleon_cms.admin.custom_field.message.custom_updated')
      redirect_to action: :edit, id: @field_group.id
    else
      flash[:error] = "<b>#{cama_t('errors_found_msg')}</b><br>#{@field_group.errors.full_messages.join(', ')}"
      render 'form'
    end
  end

  def new
    add_breadcrumb I18n.t("camaleon_cms.admin.button.new")
    @field_group ||= current_site.field_groups.new
    render 'form'
  end

  # create a new custom field group
  def create
    @field_group = current_site.field_groups.new(group_params)
    if @field_group.save
      flash[:notice] = t('camaleon_cms.admin.custom_field.message.custom_updated')
      redirect_to action: :edit, id: @field_group.id
    else
      flash[:error] = "<b>#{cama_t('errors_found_msg')}</b><br>#{@field_group.errors.full_messages.join(', ')}"
      new
    end
  end

  # destroy a custom field group
  def destroy
    @field_group.destroy
    flash[:notice] = t('camaleon_cms.admin.custom_field.message.deleted', default: "Custom Field Group Deleted.")
    redirect_to action: :index
  end

  # reorder custom fields group
  def reorder
    params[:values].to_a.each_with_index do |value, index|
      current_site.field_groups.find(value).update_column(:position, index)
    end
    json = { size: params[:values].size }
    render json: json
  end

  def list
    p = params.permit(:post_type, :post_id, :categories => [])
    args = {}
    if p[:post_id].present?
      post = @current_site.the_post(p[:post_id].to_i)
      post.update_categories(p[:categories])
    else
      post = CamaleonCms::Post.new
      post.taxonomy_id = p[:post_type].to_i
      args[:cat_ids] = p[:categories]
    end
    render partial: 'camaleon_cms/admin/settings/custom_fields/render', :locals => {record: post, field_groups: post.get_field_groups(args), show_shortcode: true}
  end

  private

  def group_params
    data = params.require(:custom_field_group).permit(:name, :is_repeat, :description)
    data[:record_type], data[:record_id], data[:kind]  = params[:custom_field_group][:assign_group].split(',')
    data[:fields_attributes] = params[:fields].permit!.to_h.map.with_index do |(key, data), index|
      data.slice(:id, :name, :slug, :description).merge(settings: params[:field_options][key].permit!, position: index)
    end
    data
  end

  def set_custom_field_group
    begin
      @field_group = current_site.field_groups.find(params[:id])
    rescue
      flash[:error] = t('camaleon_cms.admin.custom_field.message.custom_group_error')
      redirect_to cama_admin_path
    end
  end
end
