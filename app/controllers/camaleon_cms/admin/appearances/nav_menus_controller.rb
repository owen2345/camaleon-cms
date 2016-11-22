class CamaleonCms::Admin::Appearances::NavMenusController < CamaleonCms::AdminController
  add_breadcrumb I18n.t("camaleon_cms.admin.sidebar.appearance")
  add_breadcrumb I18n.t("camaleon_cms.admin.sidebar.menus")
  before_action :check_menu_permission
  def index
    if params[:id].present?
      @nav_menu = current_site.nav_menus.find_by_id(params[:id])
    elsif params[:slug].present?
      @nav_menu = current_site.nav_menus.find_by_slug(params[:slug])
    else
      @nav_menu = current_site.nav_menus.first
    end
    @post_types = current_site.post_types
    add_asset_library("nav_menu")
    render "index"
  end

  def new
    @nav_menu = current_site.nav_menus.new
    render partial: 'form'
  end

  def create
    nav_menu = current_site.nav_menus.new(params.require(:nav_menu).permit!)
    nav_menu.save
    flash[:notice] = t('.created_menu', default: 'Created Menu')
    redirect_to action: :index, id: nav_menu.id
  end

  def update
    nav_menu = current_site.nav_menus.find(params[:id])
    nav_menu.update(params.require(:nav_menu).permit!)
    flash[:notice] = t('.updated_menu', default: 'Menu updated')
    redirect_to action: :index, id: nav_menu.id
  end

  def edit
    @nav_menu = current_site.nav_menus.find(params[:id])
    render partial: 'form'
  end

  def destroy
    current_site.nav_menus.find(params[:id]).destroy
    flash[:notice] = t('.deleted_menu', default: 'Menu destroyed')
    redirect_to action: :index
  end

  def custom_settings
    @nav_menu = current_site.nav_menus.find(params[:nav_menu_id])
    @nav_menu_item = current_site.nav_menu_items.find(params[:id])
    render "_custom_fields", layout: "camaleon_cms/admin/_ajax"
  end

  def save_custom_settings
    @nav_menu_item = current_site.nav_menu_items.find(params[:id])
    @nav_menu_item.set_field_values(params.require(:field_options).permit!)
    render nothing: true
  end

  # render edit external menu item
  def edit_menu_item
    render "_external_menu", layout: false, locals: {nav_menu: current_site.nav_menus.find(params[:nav_menu_id]), menu_item: current_site.nav_menu_items.find(params[:id])}
  end

  # update an external menu item
  def update_menu_item
    @nav_menu = current_site.nav_menus.find(params[:nav_menu_id])
    item = current_site.nav_menu_items.find(params[:id])
    item.update_menu_item(parse_external_menu(params))
    item.set_options(params.require(:options).permit!) if params[:options].present?
    render partial: 'menu_items', locals: {items: [item], nav_menu: @nav_menu}
  end

  def delete_menu_item
    # @nav_menu = current_site.nav_menus.find(params[:nav_menu_id])
    current_site.nav_menu_items.find(params[:id]).destroy
    render nothing: true
  end

  # update the reorder of items
  def reorder_items(items = nil, parent_id = nil, is_root = true)
    items = params[:items] if items.nil?
    parent_id = params[:nav_menu_id] if parent_id.nil?
    items.each do |index, _item|
      item = current_site.nav_menu_items.find(_item['id'])
      item.update(parent_id: parent_id, term_order: index)
      reorder_items(_item['children'], _item['id'], false) if _item['children'].present?
    end
    render(inline: '') if is_root
  end

  # add items to specific nav-menu
  def add_items
    items = []
    @nav_menu = current_site.nav_menus.find(params[:nav_menu_id])
    if params[:external].present?
      item = @nav_menu.append_menu_item(parse_external_menu(params[:external]))
      item.set_options(params[:external].require(:options).permit!) if params[:external][:options].present?
      items << item
    end

    if params[:custom_items].present? # custom menu items
      params[:custom_items].each do |index, item|
        item = @nav_menu.append_menu_item({label: item['label'], link: item['url'], type: 'external'})
        items << item
      end
    end

    if params[:items].present?
      params[:items].each do |index, item|
        item = @nav_menu.append_menu_item({label: 'auto', link: item['id'], type: item['kind']})
        items << item
      end
    end
    render partial: 'menu_items', locals: {items: items, nav_menu: @nav_menu}
  end

  private
  def parse_menu_item(nav_menu_item)
    begin
      case nav_menu_item.kind
        when 'post'
          post = CamaleonCms::Post.find(nav_menu_item.url).decorate
          return false unless post.status == 'published'
          {name: post.the_title(locale: @frontend_locale), url_edit: post.the_edit_url }
        when 'category'
          category = CamaleonCms::Category.find(nav_menu_item.url).decorate
          {name: category.the_title, url_edit: category.the_edit_url}
        when 'post_tag'
          post_tag = CamaleonCms::PostTag.find(nav_menu_item.url).decorate
          {name: post_tag.the_title, url_edit: post_tag.the_edit_url}
        when 'post_type'
          post_type = CamaleonCms::PostType.find(nav_menu_item.url).decorate
          {name: post_type.the_title, url_edit: post_type.the_edit_url}
        when 'external'
          {name: nav_menu_item.name.to_s}
        else
          false
      end
    rescue => e
      puts "@@@@@@@@@@@@@@@@@@@@@@@@@ Skipped menu for: #{e.message} (#{nav_menu_item})"
      false
    end
  end
  helper_method :parse_menu_item

  def check_menu_permission
    authorize! :manage, :nav_menu
  end

  # return params to be saved for external menu
  def parse_external_menu(_params)
    {label: _params[:external_label], link: _params[:external_url], type: "external", target: _params[:target]}
  end
end
