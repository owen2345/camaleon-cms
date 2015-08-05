=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
module Plugins::ExportContent::ExportContentHelper


  # here all actions on plugin destroying
  # plugin: plugin model
  def export_content_on_destroy(plugin)

  end

  # here all actions on going to active
  # you can run sql commands like this:
  # results = ActiveRecord::Base.connection.execute(query);
  # plugin: plugin model
  def export_content_on_active(plugin)

  end

  # here all actions on going to inactive
  # plugin: plugin model
  def export_content_on_inactive(plugin)

  end

  # Mios
  def export_content_app_before_load

    Site.class_eval do
      # all custom field for this site
      def custom_field_all
        CustomField.where(object_class: '_fields').includes(:custom_field_group).where(parent_id: self.custom_field_groups.pluck(:id))
      end
    end

    CustomFieldGroup.class_eval do
      def post_type
        self.site.post_types.where(id:  self.objectid).first if self.object_class.include?('PostType_')
      end
      def post
        self.site.posts.where(id:  self.objectid).first if self.object_class == 'Post'
      end
    end

    PostType.class_eval do
      # group fields in content posts
      def custom_field_groups
        self.get_field_groups({kind: "all"})
      end
    end

    Post.class_eval do
      # group fields in content posts
      def custom_field_groups
        # self.post_type.site.custom_field_groups.where(object_class: 'Post', objectid:  self.id)
        self.get_field_groups({include_parent: false})
      end
    end

    Category.class_eval do
      def children_all
        children.map do |c|
          cc = c.attributes
          cc[:metas] = c.metas.to_a
          cc[:children_all] = c.children_all
          cc
        end
      end
    end

    NavMenuItem.class_eval do
      def children_all
        children.map do |c|
          cc = c.attributes
          cc[:metas] = c.metas.to_a
          cc[:children_all] = c.children_all
          cc
        end
      end
    end

    CustomField.class_eval do
      # only group field -> taxonomy
      def post_type
        case object_class
          when "PostType_Post","PostType_Category","PostType_PostTag"
            PostType.find(objectid)
        end
      end
    end
  end

  def export_content_front_before_load

  end

  def export_content_admin_before_load
    #admin_menu_append_menu_item("settings", {icon: "cloud-download", title: "Export / Import Content", url: admin_plugins_export_content_index_path}) if can? :manager, :settings
  end

  
  # functions 
  
  def load_file_content_to_db(file, options = {})
    return {errors: ['Not found json file']} unless File.exist?(file)
    content_text = File.open(file, "r").read rescue "{}"
    content_text = _parse_codes(content_text)
    begin
      data = JSON.parse(content_text).to_sym
    rescue
      return {errors: ["Content json error"]}
    end

    @_cache_ids_for_nav_menu = {post: {}, category: {}, post_tag: {}, post_type: {}}
    messages = []
    errors = []
    wars = []

    # poat_types
    if data[:post_types].present?
      data[:post_types].each do |pt|
        if options[:post_types].present? || (options[:post_type_ids].present? && options[:post_type_ids].include?(pt[:id].to_s))
          p = ActionController::Parameters.new(pt)
          post_type = current_site.post_types.where(slug: p[:slug]).first
          post_type = current_site.post_types.new(p.permit(:name, :slug, :description, :term_order, :count)) unless post_type.present?
          if post_type.save
            @_cache_ids_for_nav_menu[:post_type][pt[:id]] = post_type.id
            post_type.posts.destroy_all if options[:clear_post_type].present?
            # saved metas
            save_metas_data(post_type, pt[:metas]) if pt[:metas].present? && true
            # saved categories
            if pt[:categories].present? && true
              pt[:categories].each do |catg|
                c = ActionController::Parameters.new(catg)
                category = post_type.categories.where(slug: c[:slug]).first
                category = post_type.categories.create(c.permit(:name, :slug, :description, :term_order, :count)) unless category.present?
                if category.save
                  @_cache_ids_for_nav_menu[:category][catg[:id]] = category.id
                  save_children_categories(category, catg, post_type)
                else
                  errors << category.errors.full_messages
                end
              end
            else

            end

            # saved posts tags
            if pt[:post_tags].present? && true
              pt[:post_tags].each do |ptag|
                ptg = ActionController::Parameters.new(ptag)
                post_tag = post_type.post_tags.where(slug: ptg[:slug]).first
                post_tag = post_type.post_tags.new(ptg.permit(:name, :slug, :description, :term_order, :count)) unless post_tag.present?
                if post_tag.save
                  @_cache_ids_for_nav_menu[:post_tag][ptag[:id]] = post_tag.id
                else
                  errors << post_tag.errors.full_messages
                end
              end
            else

            end

            # save field group
            if pt[:custom_field_groups].present?
              save_field_group(post_type, pt[:custom_field_groups], post_type)
            end
            save_field_values(post_type, pt[:field_values])

            ### POSTS ###
            if pt[:posts].present? && true
              pt[:posts].each do |pts|
                next unless pts[:status] == 'published'
                post_data = ActionController::Parameters.new(pts)
                post = post_type.posts.new(post_data.permit(:title, :slug, :content, :content_filtered, :status, :published_at, :visibility, :visibility_value, :post_class, :user_id))
                post.slug = current_site.get_valid_post_slug(post.slug)
                if post.save
                  wars << "Post #{post.title} slug changed for duplicity." if post.slug != pts[:slug]
                  @_cache_ids_for_nav_menu[:post][pts[:id]] = post.id
                  # saved post meta
                  save_metas_data(post, pts[:metas]) if pts[:metas].present?
                  # assign categories
                  if pts[:categories].present?
                    pts[:categories].each do |ct|
                      catg_id = current_site.full_categories.find_by_slug(ct[:slug]).id rescue nil
                      post.term_relationships.where({term_taxonomy_id: catg_id}).first_or_create if catg_id.present?
                    end
                  end
                  # assign post_tags
                  if pts[:post_tags].present?
                    pts[:post_tags].each do |ptg|
                      post_t_id = post_type.post_tags.find_by_slug(ptg[:slug]).id rescue nil
                      post.term_relationships.where({term_taxonomy_id: post_t_id}).first_or_create if post_t_id.present?
                    end
                  end
                  # add custom fields
                  if pts[:custom_field_groups].present?
                    save_field_group(post, pts[:custom_field_groups], post_type)
                  end
                  save_field_values(post, pts[:field_values])
                else
                  errors << post.errors.full_messages
                end
              end
            else
              wars << "Not import post in: #{post_type.name}"
            end

            messages << "Saved Post Type: #{post_type.name}"
          else
            errors << post_type.errors.full_messages
          end
        end
      end
    else
      wars << "Not import post types"
    end

    # nav_menus
    if data[:nav_menus].present?
        current_site.nav_menus.destroy_all if options[:clear_nav_menus].present?
        data[:nav_menus].each do |nav_m_data|
          if options[:nav_menus].present? || (options[:nav_menu_ids].present? && options[:nav_menu_ids].to_i.include?(nav_m_data[:id].to_i))
            c = ActionController::Parameters.new(nav_m_data)
            nav_menu = current_site.nav_menus.where(slug: c[:slug]).first_or_create(c.permit(:name, :slug, :description, :term_order, :count))
            if nav_menu.valid?
              messages << "Saved Nav Menu: #{nav_menu.name}"
              save_children_nav_menu(nav_menu, nav_m_data[:children])
            else
              errors << nav_menu.errors.full_messages
            end
          end

        end

    end

    # themes
    if data[:themes].present? && options[:theme_import].present?
      data_theme = data[:themes]
      # saved post meta
      save_metas_data(current_theme, data_theme[:metas]) if data_theme[:metas].present?
      save_field_group(current_theme, data_theme[:get_field_groups]) if data_theme[:get_field_groups].present?
      save_field_values(current_theme, data_theme[:field_values])
      messages << "Saved Theme: #{current_theme.the_title}"
    end

    # plugins
    if data[:plugins].present?
      r = {data: data, messages: messages, errors: errors}; hooks_run("on_import", r);
      messages = r[:messages]
      errors = r[:errors]
    end

    return {messages: messages, errors: errors, warnings: wars}
  end

  def load_file_content_preview(file)
    return {errors: ['Not found json file']} unless File.exist?(file)
    content_text = File.open(file, "r").read rescue "{}"
    content_text = _parse_codes(content_text)
    begin
      data = JSON.parse(content_text).to_sym
    rescue
      return {errors: ["Content json error"]}
    end

    data_return = {plugins: {}, post_type: {}, nav_menu: {}, themes: nil}

    # post_types
    if data[:post_types].present?
      data[:post_types].each do |pt|
        data_return[:post_type][pt[:id]] = pt[:name]
      end
    end


    # plugins
    if data[:plugins].present?
      data[:plugins].each do |key, plugin_data|
        data_return[:plugins]["#{key}"] = key
      end
    end


    # nav_menus
    if data[:nav_menus].present?
        data[:nav_menus].each do |nav_m_data|
          data_return[:nav_menu][nav_m_data[:id]] = nav_m_data[:name]
        end
    end
    # themes
    if data[:themes].present?
          data_return[:themes] = 'Import Theme'
    end

    return data_return
  end

  def export_content_plugin_options(arg)
    arg[:links] << link_to(t('plugin.export_content.import_export'), admin_plugins_export_content_settings_path)
  end

  # convert url codes into current urls
  def _parse_codes(text)
    text.gsub("{media_url}", "#{root_url}media/#{current_site.id}")
        .gsub("{theme_url}", "#{root_url}assets/themes/#{current_site.get_theme_slug}/assets/")
        .gsub("{themes_url}", "#{root_url}assets/themes/")
        .gsub("{root_url}", "#{root_url}")
  end

  # convert current urls into url codes
  def _parse_codes2(text)
    text.gsub("#{root_url}media/#{current_site.id}", "{media_url}")
               .gsub("#{root_url}", "{root_url}")
  end

  private
  def save_metas_data(object, metas = [])
    object.metas.destroy_all
    metas.each do |meta|
      object.metas.create({key: meta[:key], value: meta[:value]})
    end
  end

  def save_children_categories(parent, data = {}, post_type)
    if data[:get_field_groups].present?
      save_field_group(parent, data[:get_field_groups], post_type)
    end
    save_field_values(parent, data[:field_values])
    if data[:children_all].present?
      data[:children_all].each do |catg|
        c = ActionController::Parameters.new(catg)
        category = parent.children.where(slug: c[:slug]).first
        category = parent.children.new(c.permit(:name, :slug, :description, :term_order, :count)) unless category.present?
        if category.save
          @_cache_ids_for_nav_menu[:category][catg[:id]] = category.id
          save_children_categories(category, catg, post_type)
        end
      end
    end
  end

  def save_children_nav_menu(parent, children_data = [])

    if children_data.present?
      children_data.each do |nav_item_data|
        c = ActionController::Parameters.new(nav_item_data)
        nav_item = parent.children.where(slug: c[:slug]).first_or_create(c.permit(:name, :slug, :description, :term_order, :count))
        if nav_item.valid?
          # saved post meta
          if nav_item_data[:metas].present?
            metas = []
            nav_item_data[:metas].each do |meta|
              if meta[:key] == '_default'
                orig = JSON.parse(meta[:value]).to_sym
                begin
                  orig[:object_id] = @_cache_ids_for_nav_menu[orig[:type].to_sym][orig[:object_id].to_i].to_s if @_cache_ids_for_nav_menu[orig[:type].to_sym].present? && @_cache_ids_for_nav_menu[orig[:type].to_sym][orig[:object_id].to_i].present?
                end

                meta[:value] = orig.to_json
              end
              metas << meta
            end
            save_metas_data(nav_item, metas)
          end

          save_children_nav_menu(nav_item, nav_item_data[:children_all])
        end
      end
    end
  end
  def save_field_group(parent, groups, post_type = nil)
    groups.each do |fgroup|
      fg = ActionController::Parameters.new(fgroup)
      #field_group = current_site.custom_field_groups.where(slug: fgroup[:slug]).first_or_create(fg.permit(:object_class, :name, :slug, :description, :is_repeat, :objectid, :field_order))
      field_group = (fg[:object_class].include?('PostType_') ? post_type : parent).add_custom_field_group(fg.permit(:object_class, :name, :slug, :description, :is_repeat, :field_order),  fg[:object_class].gsub('PostType_',''))

      if field_group.valid?
        save_metas_data(field_group, fgroup[:metas])
        if fgroup[:fields].present?
          fgroup[:fields].each do |fild|
            fd = ActionController::Parameters.new(fild)
            field = field_group.fields.where(slug: fild[:slug]).first_or_create!(fd.permit(:name, :slug, :description, :is_repeat, :field_order))
            if field.valid?
              save_metas_data(field, fild[:metas])if fild[:metas].present?
              # save_field_values(parent, field, fild[:values])if fild[:values].present?
            end
          end
        end
      else
        #errors << field_group.errors.full_messages
      end
    end
  end

  def save_field_values_(object, field, values)
    values.each do |fv|
      fv_data = ActionController::Parameters.new(fv)
      fv_data[:custom_field_id] = field.id
      object.field_values.where(custom_field_id: fv_data[:custom_field_id], custom_field_slug: fv_data[:custom_field_slug]).first_or_create!(fv_data.permit(:custom_field_id, :term_order, :object_class, :value, :custom_field_slug))
    end
  end

  def save_field_values(object, values)
    values.each do |fv|
      object.save_field_value(fv[:custom_field_slug], fv[:value], fv[:term_order], false)
    end
  end
end

