=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class Plugins::ExportContent::AdminController < Apps::PluginsAdminController
  def settings
    # here your actions for admin panel
  end

  # here add your custom functions
  def export
    obj = {}
    post_types = current_site.post_types.where(id: params[:data][:pt])
    obj_group = {:get_field_groups => {:include => [:metas, {:fields => {:include => [:metas]  }}]  }}
    obj_group_post = {:custom_field_groups => {:include => [:metas, {:fields => {:include => [:metas]  }}]  }}
    if true && post_types.present?
      post_types_text = post_types.to_json(:include => [
                                               :metas,
                                               {:categories => {:methods => [:children_all], :include => [obj_group, :field_values]}},
                                               :post_tags,
                                               {:posts => {:include => [obj_group_post, :metas, :field_values, {:categories => {:only => [:id, :name, :slug] }}, {:post_tags => {:only => [:id, :name, :slug] }}]}},
                                               obj_group_post,
                                               :field_values
                                           ])
      obj[:post_types] = JSON.parse(post_types_text)
    end

    obj[:plugins] = {}
    if current_site.plugin_installed?('slider_basic') && params[:data][:slider_basic].present?
      obj[:plugins][:slider_basics] = JSON.parse(current_site.slider_basics.to_json(:include => [obj_group, :field_values]))
    end

    obj[:nav_menus] = JSON.parse(current_site.nav_menus.to_json(:include => [{:children => {:methods => [:children_all], :include => [:metas]}}])) if params[:data][:nav_menus].present?

    obj[:themes] = JSON.parse(current_theme.to_json(:include => [:metas, obj_group, :field_values])) if params[:data][:themes].present?
    r = {obj: obj}; hooks_run("on_export",r); obj = r[:obj];
    if params[:data][:show_json].present?
      render json: _parse_codes2("#{obj.to_json}")
    else
      send_data _parse_codes2("#{obj.to_json}"), :filename => "#{current_site.the_title}-#{Time.now.to_i}.json"
    end
  end

  def import
    case params[:method]
      when 'load_json'
        file = File.join(Rails.public_path, params[:url]) if params[:url].present?
        file = Rails.root.join(params[:file]) if params[:file].present?
        render json: load_file_content_to_db(file, params[:filter])
      when 'preview'
        file = File.join(Rails.public_path, params[:url]) if params[:url].present?
        file = Rails.root.join(params[:file]) if params[:file].present?
        render json: load_file_content_preview(file)
      else
        render json: {errors: 'Not Found'}
    end

  end
end