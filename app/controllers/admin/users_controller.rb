=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class Admin::UsersController < AdminController
  before_action :validate_role, except: [:profile, :profile_edit]
  before_action :set_user, only: ['show','edit','update','destroy']

  def index
    @users = current_site.users.paginate(:page => params[:page], :per_page => current_site.admin_per_page)
  end

  def profile
    @user = current_user
  end

  def profile_edit
    @user = current_user
    if params[:meta]
      @user.set_meta_from_form(params[:meta])
      render json: {message: 'update'}
    end

    if params[:user]
      render json: @user.update(params[:user].permit(:username, :email)) ? {message: 'update'} : {errors: @user.errors.full_messages.join(', ')}
    end

    if params[:password]
      if @user.authenticate(params[:password][:password_old])
         render json: @user.update(params[:password]) ? {message: 'update'} : {errors: @user.errors.full_messages.join(', ')}
      else
        render json: {errors: t('admin.users.message.incorrect_old_password')}
      end
    end
  end

  def show
    render 'profile'
  end

  def edit
    admin_breadcrumb_add("#{t('admin.button.edit')}")
    render 'form'
  end

  def update
    if @user.update(params[:user])
      @user.set_meta_from_form(params[:meta]) if params[:meta].present?
      @user.set_field_values(params[:field_options])
      flash[:notice] = t('admin.users.message.updated')
      redirect_to action: :index
    else
      render 'form'
    end
  end

  def updated_ajax
    @user = current_site.users.find(params[:user_id])
    if params[:meta]
      @user.set_meta_from_form(params[:meta])
      render json: {message: 'update'}
    end

    if params[:user]
      render json: @user.update(params[:user].permit(:username, :email)) ? {message: 'update'} : {errors: @user.errors.full_messages.join(', ')}
    end

    if params[:password]
      if @user.authenticate(params[:password][:password_old])
        render json: @user.update(params[:password]) ? {message: 'update'} : {errors: @user.errors.full_messages.join(', ')}
      else
        render json: {errors: t('admin.users.message.incorrect_old_password')}
      end
    end
  end

  def new
    @user = current_site.users.new
    render 'form'
  end

  def create
    user_data = params[:user]

    @user = current_site.users.new(user_data)
    if @user.save
      @user.set_meta_from_form(params[:meta]) if params[:meta].present?
      @user.set_field_values(params[:field_options])
      flash[:notice] = t('admin.users.message.created')
      redirect_to action: :index
    else
      render 'form'
    end
  end

  def destroy
    flash[:notice] = t('admin.users.message.deleted') if @user.destroy
    redirect_to action: :index
  end

  private

  def validate_role
    authorize! :manager, :users
  end

  def set_user
    begin
      @user = current_site.users.find(params[:id])
    rescue
      flash[:error] = t('admin.users.message.error')
      redirect_to admin_path
    end
  end
end
