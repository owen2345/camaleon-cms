=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
module Plugins::FrontCache::FrontCacheHelper

  # save as cache all pages configured on settings of this plugin for public users
  def front_cache_front_before_load
    return if signin?
    cache_key = front_cache_get_key
    if page_cache_exist?(cache_key) # recover cache file
      Rails.logger.info "============================================== readed cache: #{cache_key}"
      render text: File.read(page_cache_get(cache_key)).gsub("{{form_authenticity_token}}", form_authenticity_token)
      return
    end

    @caches = current_site.get_meta("front_cache_elements")
    @_plugin_do_cache = false
    if @caches[:paths].include?(front_request_key) || (params[:action] == "index" && @caches[:home].present?) # cache paths and home page
      @_plugin_do_cache = true
    elsif params[:action] == "post" && !params[:draft_id].present?
      post = current_site.posts.find_by_slug(params[:slug]).decorate
      if post.can_visit?
        @post = post
        @post_type = post.the_post_type
        @_plugin_do_cache = true if can_cache_page?
      end
    end
  end


  def front_cache_front_after_load
    cache_key = front_cache_get_key
    # expire pages if already exist flash messages
    if flash.keys.present?
      expire_page(current_site.cache_prefix("#{cache_key}"))
      expire_page(current_site.cache_prefix("___#{cache_key}"))
    end

    if @_plugin_do_cache && !flash.keys.present?
      cache_page(response.body
                     .gsub(/csrf-token" content="(.*?)"/, 'csrf-token" content="{{form_authenticity_token}}"')
                     .gsub(/name="authenticity_token" value="(.*?)"/, 'name="authenticity_token" value="{{form_authenticity_token}}"'), cache_key, false)
      Rails.logger.info "============================================== cache saved as: #{cache_key}"
    end
  end

  # on install plugin
  def front_cache_on_active(plugin)
    current_site.set_meta("front_cache_elements", {paths: [],
        posts: [],
        post_types: [current_site.post_types.where(slug: "page").first.id],
        skip_posts: [],
        home: true,
        cache_login: true}) unless current_site.get_meta("front_cache_elements", nil).present?
  end

  # on uninstall plugin
  def front_cache_on_inactive(plugin)
    # current_site.delete_meta("front_cache_elements")
  end

  # cache actions (for logged users)
  def front_cache_on_render(args)
    return nil
    return if args[:options].include?(:skip_cache_action) || !signin? # avoid recursive calling
    if params[:controller] == "frontend"
      do_cache = false
      @caches = current_site.get_meta("front_cache_elements")
      return unless @caches[:cache_login]
      if @caches[:paths].include?(front_request_key) || (params[:action] == "index" && @caches[:home].present?) # cache paths and home page
        do_cache = true
      elsif params[:action] == "post" && !params[:draft_id].present?
        do_cache = true if can_cache_page?
      end

      cache_key = front_cache_get_key("___")
      if do_cache # save or recovery cache
        if args[:context].controller.page_cache_exist?(cache_key) # recover cache file
          args[:options][:skip_cache_action] = true
          args[:options][:text] = File.read(args[:context].controller.page_cache_get(cache_key))
          args[:options].delete(:file)
          return
        end
        Thread.abort_on_exception=true
        Thread.new do
          options = args[:options].dup
          options[:layout] = false
          options[:skip_cache_action] = true
          args[:context].controller.cache_page(args[:context].controller.render_to_string(options), cache_key, false)
        end
      end
    end
  end

  # expire cache for a page after comment registered or updated
  def front_cache_before_load
    PostComment.class_eval do
      after_save :clear_front_page_cache
      def clear_front_page_cache
        self.post.decorate.front_clear_cache
      end
    end

    PostDecorator.class_eval do
      def front_clear_cache
        a = ActionController::Base.new
        object.slug.translations_array.each do |t|
          a.expire_page(h.current_site.cache_prefix("#{t}"))
          a.expire_page(h.current_site.cache_prefix("___#{t}"))
        end
      end
    end
  end

  def front_cache_plugin_options(arg)
    arg[:links] << link_to(t('plugin.front_cache.settings'), admin_plugins_front_cache_settings_path)
    arg[:links] << link_to(t('plugin.front_cache.clean_cache'), admin_plugins_front_cache_clean_path)
  end

  # save as cache all post requests
  def front_cache_post_requests
    if (request.post? || request.patch?)
      # current_site.set_meta("last_submit", Time.now.to_s)
      front_cache_clean()
    end
  end

  # clear all frontend cache files
  def front_cache_clean
    FileUtils.rm_f(cache_store.cache_path) # clear fragment caches
    FileUtils.rm_rf(File.join(Rails.application.config.action_controller.page_cache_directory, current_site.id.to_s)) # clear site pages cache
  end

  private
  def front_cache_get_key(prefix = "")
    k = front_request_key.parameterize
    current_site.cache_prefix("#{prefix}#{ k.present? ? k : "home"}")
  end

  # check if current post can be cached (skip private pages)
  def can_cache_page?
    !@caches[:skip_posts].include?(@post.id.to_s) && (@post.can_visit? && @post.visibility != "private") && (@caches[:post_types].include?(@post_type.id.to_s) || @caches[:posts].include?(@post.id.to_s)) rescue false
  end

  def front_request_key
    request.path_info.split("?").first
  end

end