=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class CamaleonCms::Admin::Appearances::NavMenusController < CamaleonCms::AdminController
  add_breadcrumb I18n.t("camaleon_cms.admin.sidebar.appearance")
  add_breadcrumb I18n.t("camaleon_cms.admin.sidebar.menus")
  def menu
    authorize! :manager, :menu
    unless params[:new].present?
      if params[:id].present?
        @nav_menu = current_site.nav_menus.find_by_id(params[:id])
        if request.delete? && @nav_menu.present?
          @nav_menu.destroy
          flash[:notice] = t('camaleon_cms.admin.menus.message.deleted')
          redirect_to action: :menu
          return
        end
      end

      unless @nav_menu.present?
        if params[:slug].present?
          @nav_menu = current_site.nav_menus.where({slug: params[:slug]}).first
        else
          @nav_menu = current_site.nav_menus.last
        end
      end

    end
    @nav_menu = current_site.nav_menus.new unless @nav_menu.present?
    items = []
    unless @nav_menu.new_record?
      items = get_nav_items(@nav_menu.children)
    end
    @items = items

    @nav_menus = current_site.nav_menus.all
    @post_types = current_site.post_types
    add_asset_library("nav_menu")
    render "index"
  end

  # save changes of the menu
  def save
    authorize! :manager, :menu
    unless params[:nav_menu][:id].present?   # new
      menu_data = params[:nav_menu]
      @nav_menu = current_site.nav_menus.new(menu_data)
      if @nav_menu.save
        flash[:notice] = t('camaleon_cms.admin.menus.message.created')
        render json: {new: 1, nav_menu: @nav_menu, redirect: cama_admin_appearances_nav_menus_menu_path({id: @nav_menu.id})}
      else
        render json: {error: t('camaleon_cms.admin.menus.message.error_menu')}
      end
    else
      @nav_menu = current_site.nav_menus.find(params[:nav_menu][:id])
      if @nav_menu.update(params[:nav_menu])
        @nav_menu.add_menu_items(params[:menu_data])

        if params[:nav_menu_location].present?
          params[:nav_menu_location].each do |location|
            current_site.set_option("_nav_menu_#{location}", @nav_menu.id)
          end
        end
        render json: {update: 1, nav_menu: @nav_menu}
      else
        render json: {error: t('camaleon_cms.admin.menus.message.error_menu')}
      end
    end
  end

  # show external menu form
  def form
    if params[:custom_fields].present?
      if params[:item_id] == 'undefined'
        @nav_menu = current_site.nav_menus.find_by_id(params[:menu_id])
      else
        @nav_menu = current_site.nav_menu_items.find_by_id(params[:item_id])
      end
      render "_custom_fields", layout: "camaleon_cms/admin/_ajax"
    else
      render "_external_menu", layout: false, locals: {submit: true}
    end
  end

  private

  def get_nav_items(menu_items, parent_id = 0)
    items = []
    menu_items.eager_load(:metas).each do |nav_item|
      object = _get_object_nav_menu(nav_item)
      if object.present?
        items << {id: nav_item.id, label: object[:name], link: nav_item.options[:object_id], url_edit: object[:url_edit], type: nav_item.options[:type], parent: parent_id.to_i, fields: "#{nav_item.get_field_values_hash(true).to_json}"}
        items += get_nav_items(nav_item.children, nav_item.id)
      end
    end
    return items
  end

  def _get_object_nav_menu(nav_menu_item)
    begin
      case nav_menu_item.get_option('type')
        when 'post'
          post = CamaleonCms::Post.find(nav_menu_item.get_option('object_id')).decorate
          return false unless post.status == 'published'
          {link: post.the_url, name: post.the_title, url_edit: post.the_edit_url }
        when 'category'
          category = CamaleonCms::Category.find(nav_menu_item.get_option('object_id')).decorate
          {link: category.the_url, name: category.the_title, url_edit: category.the_edit_url}
        when 'post_tag'
          post_tag = CamaleonCms::PostTag.find(nav_menu_item.get_option('object_id')).decorate
          {link: post_tag.the_url, name: post_tag.the_title, url_edit: post_tag.the_edit_url}
        when 'post_type'
          post_type = CamaleonCms::PostType.find(nav_menu_item.get_option('object_id')).decorate
          {link: post_type.the_url, name: post_type.the_title, url_edit: post_type.the_edit_url}
        when 'external'
          {link: nav_menu_item.get_option('object_id'), name: nav_menu_item.name.to_s}
        else
          false
      end
    rescue => e
      puts "@@@@@@@@@@@@@@@@@@@@@@@@@ Skipped menu for: #{e.message} (#{nav_menu_item})"
      false
    end
  end
end
