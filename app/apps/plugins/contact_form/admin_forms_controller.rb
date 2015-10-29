=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class Plugins::ContactForm::AdminFormsController < CamaleonCms::Apps::PluginsAdminController
  before_action :set_form, only: ['show','edit','update','destroy']
  add_breadcrumb I18n.t("plugin.contact_form.contact_form"), :admin_plugins_contact_form_admin_forms_path

  def index
    # here your actions for admin panel
    @forms = current_site.contact_forms.where("parent_id is null").all
    @forms = @forms.paginate(:page => params[:page], :per_page => current_site.admin_per_page)
  end

  def edit
    add_breadcrumb I18n.t("camaleon_cms.admin.button.edit")
    append_asset_libraries({"plugin_contact_form"=> { js: [plugin_asset_path("js/contact_form.js")], css: [plugin_asset_path("css/contact-form.css")] }})
    render "edit"
  end

  def update
    if @form.update(params[:plugins_contact_form_models_contact_form])

      settings = {"railscf_mail" => params[:railscf_mail], "railscf_message" => params[:railscf_message], "railscf_form_button" => params[:railscf_form_button]}.to_json
      current_site.contact_forms.where(id: @form.id).update_or_create({settings: fix_meta_value(settings)})
      current_site.contact_forms.where(id: @form.id).update_or_create({value: params[:meta]})

      flash[:notice] = t('camaleon_cms.admin.message.updated_success')
      redirect_to action: :edit, id: @form.id
    else
      edit
    end
  end

  def create

    params[:plugins_contact_form_models_contact_form][:value] = {"fields" => []}.to_json
    params[:plugins_contact_form_models_contact_form][:settings] = {}.to_json

    data_form = params[:plugins_contact_form_models_contact_form]
    @form = current_site.contact_forms.new(data_form)

    if @form.save
      flash[:notice] = "#{t('plugin.contact_form.message.save')}"
      redirect_to action: :edit, id: @form.id
    else
      flash[:error] = @form.errors.full_messages.join(', ')
      redirect_to action: :index
    end
  end

  def destroy
    flash[:notice] = "#{t('plugin.contact_form.message.delete')}" if @form.destroy

    redirect_to action: :index
  end

  def responses
    @form = current_site.contact_forms.where({id: params[:admin_form_id]}).first
    values = JSON.parse(@form.value).to_sym

    @op_fields = values[:fields]
    @forms = current_site.contact_forms.where({parent_id: @form.id})
    @forms = @forms.paginate(:page => params[:page], :per_page => current_site.admin_per_page)
  end

  def manual

  end

  # here add your custom functions
  private
  def set_form
    begin
      @form = current_site.contact_forms.find_by_id(params[:id])
    rescue
      flash[:error] = "Error form class"
      redirect_to cama_admin_path
    end
  end
end