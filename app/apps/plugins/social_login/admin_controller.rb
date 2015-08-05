=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class Plugins::SocialLogin::AdminController < Apps::PluginsAdminController
  skip_before_filter :authenticate, only: [:social_callback, :setup]

  def index

    # here your actions for admin panel
  end

  # This sets the access to social networks registered on the site with public and private keys
  def setup

    @site = current_site

    request.env['omniauth.strategy'].options[:consumer_key] = @site.get_option('twitter_public_key')  if @site.get_option('twitter_public_key').present?
    request.env['omniauth.strategy'].options[:consumer_secret] = @site.get_option('twitter_secret_key') if @site.get_option('twitter_secret_key').present?

    request.env['omniauth.strategy'].options[:client_id] = @site.get_option('facebook_public_key')  if @site.get_option('facebook_public_key').present?
    request.env['omniauth.strategy'].options[:client_secret] = @site.get_option('facebook_secret_key') if @site.get_option('facebook_secret_key').present?

    request.env['omniauth.strategy'].options[:client_id] = @site.get_option('google_public_key')   if @site.get_option('google_public_key').present?
    request.env['omniauth.strategy'].options[:client_secret] = @site.get_option('google_secret_key')  if @site.get_option('google_secret_key').present?

    render :text => "Setup complete.", :status => 404

  end

  # show plugin settings
  def settings
    @site = current_site
  end

  # This saves the settings plugin
  def save_settings
    @site = current_site
    if @site.update(params[:social])
      @site.set_options_from_form(params[:meta]) if params[:meta].present?
      flash[:notice] = t('admin.settings.message.site_updated')
      redirect_to action: :settings
    else
      redirect_to admin_plugins_path
    end

  end

  # This unlinks a social network of a user
  # destroys social network linked to a user, @social.destroy
  def social_logout
    @social = current_site.social_login.where(["provider = ? and user_id = ?", params[:social], params[:userid]]).first()

    if @social.present?
      params[:notice] = "#{t('plugin.social_login.message.unlink_social_network')}" if @social.destroy
      render json: params
    else
      params[:notice] = "#{t('plugin.social_login.message.social_network_unrelated')}"
      render json: params
    end

  end

  # This links a social network of a user
  # social network adds a user to the site
  # This accesses the system using data from the gem OmniAuth
  def social_callback

    @social = current_site.social_login.where(["provider = ? and uid = ?", auth_hash["provider"], auth_hash["uid"]]).first()

    if current_user.nil?
      if @social.present?
        login_user(@social.user)
      else
        user_data = {}

        if auth_hash["provider"].to_s == "facebook"
          user_data[:username] = auth_hash["info"]["first_name"]
          user_data[:email] = "#{auth_hash["info"]["first_name"].to_s}@info.com"
          user_data[:password] = auth_hash["info"]["name"]
        elsif auth_hash["provider"].to_s == "twitter"
          user_data[:username] = auth_hash["info"]["nickname"]
          user_data[:email] = "#{auth_hash["info"]["nickname"].to_s}@info.com"
          user_data[:password] = auth_hash["info"]["nickname"]
        else
          user_data[:username] = auth_hash["info"]["name"]
          user_data[:email] = "#{auth_hash["info"]["email"].to_s}"
          user_data[:password] = auth_hash["info"]["name"]
        end
        user_data[:role] = 'client'

        @user = current_site.users.new(user_data)

        if @user.save
          @social = current_site.social_login.new(user_id: @user.id, provider: auth_hash["provider"], uid: auth_hash["uid"], content: auth_hash.to_json)
          @social.save

          login_user(@social.user)
        else
          flash[:error] = "#{t('plugin.social_login.message.user_not_created')}"
          redirect_to admin_login_path
        end


      end
    else
      if @social.present?
        flash[:notice] = "#{t('plugin.social_login.message.social_network_use')}"
      else
        @social = current_site.social_login.new(user_id: current_user.id, provider: auth_hash["provider"], uid: auth_hash["uid"], content: auth_hash.to_json)
        @social.save
        flash[:notice] = "#{t('plugin.social_login.message.connected_social_network')}"
      end
      redirect_to admin_profile_edit_path
    end
  end

  # This gets the data from the network access Gem OmniAuth
  def auth_hash
    request.env["omniauth.auth"]
  end
end