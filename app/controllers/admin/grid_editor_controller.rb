=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
# Manage all templates for grid editor
class Admin::GridEditorController < AdminController
  # return all grid templates
  def index
    @grid_templates = current_site.grid_templates
    render "index", layout: false
  end

  # return new grid editor template form
  def new
    @grid_template ||= current_site.grid_templates.new
    render "form", layout: false
  end

  # return edit grid editor template form
  def edit
    @grid_template = current_site.grid_templates.find(params[:id])
    new
  end

  # update a grid editor template
  def update
    current_site.grid_templates.find(params[:id]).update(params.require(:grid_template).permit(:name, :description))
    index
  end

  # return grid template value
  def show
    render inline: current_site.grid_templates.find(params[:id]).description
  end

  # destroy a grid editor template
  def destroy
    current_site.grid_templates.find(params[:id]).destroy
    index
  end

  # create a new grid editor template
  def create
    params[:grid_template][:slug] = Time.now.to_i
    if current_site.grid_templates.create(params.require(:grid_template).permit(:name, :slug, :description))
      index
    else
      render inline: "<div class='alert alert-danger'>#{t("admin.message.form_error")}</div>"
    end
  end
end