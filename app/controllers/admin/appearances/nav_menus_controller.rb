=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class Admin::Appearances::NavMenusController < Admin::AppearancesController
  def menu
    authorize! :manager, :menu
    unless params[:new].present?
      if params[:id].present?
        @nav_menu = current_site.nav_menus.find_by_id(params[:id])
        if request.delete? && @nav_menu.present?
          @nav_menu.destroy
          flash[:notice] = t('admin.menus.message.deleted')
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
      items = get_nav_items( @nav_menu.children)
    end
    @items = items

    @nav_menus = current_site.nav_menus.all
    @post_types = current_site.post_types
    add_asset_library("nav_menu")
  end

  def save
    authorize! :manager, :menu
    unless params[:nav_menu][:id].present?   # new
      menu_data = params[:nav_menu]
      @nav_menu = current_site.nav_menus.new(menu_data)
      if @nav_menu.save
        flash[:notice] = t('admin.menus.message.created')
        render json: {new: 1, nav_menu: @nav_menu, redirect: admin_appearances_nav_menus_menu_path({id: @nav_menu.id})}
      else
        render json: {error: t('admin.menus.message.error_menu')}
      end
    else
      @nav_menu = NavMenu.find(params[:nav_menu][:id])
      if @nav_menu.update(params[:nav_menu])
        @nav_menu.add_menu_items(params[:menu_data])

        if params[:nav_menu_location].present?
          params[:nav_menu_location].each do |location|
            current_site.set_option("_nav_menu_#{location}", @nav_menu.id)
          end
        end
        render json: {update: 1, nav_menu: @nav_menu}
      else
        render json: {error: t('admin.menus.message.error_menu')}
      end
    end
  end

  def form
    render "_external_menu", layout: false, locals: {submit: true}
  end

  private

  def get_nav_items(menu_items, parent_id = 0)
    items = []
    menu_items.eager_load(:metas).each do |nav_item|
      object = _get_object_nav_menu(nav_item)

      if object.present?
        items << {id: nav_item.id, label: object[:name], link: nav_item.options[:object_id], url_edit: object[:url_edit], type: nav_item.options[:type], parent: parent_id.to_i}
        items += get_nav_items(nav_item.children, nav_item.id)
      end
    end
    return items
  end

  def _get_object_nav_menu(nav_menu_item)
    begin
      case nav_menu_item.get_option('type')
        when 'post'
          post = Post.find(nav_menu_item.get_option('object_id')).decorate
          return false unless post.status == 'published'
          {link: post.the_url, name: post.the_title, url_edit: post.the_edit_url }
        when 'category'
          category = Category.find(nav_menu_item.get_option('object_id')).decorate
          {link: category.the_url, name: category.the_title, url_edit: category.the_edit_url}
        when 'post_tag'
          post_tag = PostTag.find(nav_menu_item.get_option('object_id')).decorate
          {link: post_tag.the_url, name: post_tag.the_title, url_edit: post_tag.the_edit_url}
        when 'post_type'
          post_type = PostType.find(nav_menu_item.get_option('object_id')).decorate
          {link: post_type.the_url, name: post_type.the_title, url_edit: post_type.the_edit_url}
        when 'external'
          {link: nav_menu_item.get_option('object_id'), name: nav_menu_item.name.to_s.translate}
        else
          false
      end
    rescue
      false
    end
  end
end
