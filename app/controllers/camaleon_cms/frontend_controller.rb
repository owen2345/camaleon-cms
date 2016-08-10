=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class CamaleonCms::FrontendController < CamaleonCms::CamaleonController
  before_action :init_frontent
  include CamaleonCms::FrontendConcern
  include CamaleonCms::Frontend::ApplicationHelper
  layout Proc.new { |controller| params[:cama_ajax_request].present? ? "cama_ajax" : 'index' }
  before_action :before_hooks
  after_action :after_hooks
  # rescue_from ActiveRecord::RecordNotFound, with: :page_not_found

  # home page for frontend
  def index
    @cama_visited_home = true
    if @_site_options[:home_page].present?
      render_post(@_site_options[:home_page].to_i)
    else
      r = {layout: nil, render: "index"}; hooks_run("on_render_index", r)
      render r[:render], (!r[:layout].nil? ? {layout: r[:layout]} : {})
    end
  end

  # render category list
  def category
    begin
      @category = current_site.the_full_categories.find(params[:category_id]).decorate
      @post_type = @category.the_post_type
    rescue
      return page_not_found
    end
    @cama_visited_category = @category
    @children = @category.children.no_empty.decorate
    @posts = @category.the_posts.paginate(:page => params[:page], :per_page => current_site.front_per_page).eager_load(:metas)
    r_file = lookup_context.template_exists?("category_#{@category.the_slug}") ? "category_#{@category.the_slug}" : nil  # specific template category with specific slug within a posttype
    r_file = lookup_context.template_exists?("post_types/#{@post_type.the_slug}/category") ? "post_types/#{@post_type.the_slug}/category" : nil unless r_file.present? # default template category for all categories within a posttype
    r_file = lookup_context.template_exists?("categories/#{@category.the_slug}") ? "categories/#{@category.the_slug}" : 'category' unless r_file.present?  # default template category for all categories for all posttypes

    layout_ = lookup_context.template_exists?("layouts/post_types/#{@post_type.the_slug}/category") ? "post_types/#{@post_type.the_slug}/category" : nil unless layout_.present? # layout for all categories within a posttype
    layout_ = lookup_context.template_exists?("layouts/categories/#{@category.the_slug}") ? "categories/#{@category.the_slug}" : nil unless layout_.present? # layout for categories for all post types
    r = {category: @category, layout: layout_, render: r_file}; hooks_run("on_render_category", r)
    render r[:render], (!r[:layout].nil? ? {layout: r[:layout]} : {})
  end

  # render contents from post type
  def post_type
    begin
      @post_type = current_site.post_types.find(params[:post_type_id]).decorate
    rescue
      return page_not_found
    end
    @object = @post_type
    @cama_visited_post_type = @post_type
    @posts = @post_type.the_posts.paginate(:page => params[:page], :per_page => current_site.front_per_page).eager_load(:metas)
    @categories = @post_type.categories.no_empty.eager_load(:metas).decorate
    @post_tags = @post_type.post_tags.eager_load(:metas)
    r_file = lookup_context.template_exists?("post_types/#{@post_type.the_slug}") ? "post_types/#{@post_type.the_slug}" : "post_type"
    layout_ = lookup_context.template_exists?("layouts/post_types/#{@post_type.the_slug}") ? "post_types/#{@post_type.the_slug}" : nil
    r = {post_type: @post_type, layout: layout_, render: r_file};  hooks_run("on_render_post_type", r)
    render r[:render], (!r[:layout].nil? ? {layout: r[:layout]} : {})
  end

  # render contents for the post tag
  def post_tag
    begin
      if params[:post_tag_slug].present?
        @post_tag = current_site.post_tags.find_by_slug(params[:post_tag_slug]).decorate
      else
        @post_tag = current_site.post_tags.find(params[:post_tag_id]).decorate
      end
      @post_type = @post_tag.the_post_type
    rescue
      return page_not_found
    end
    @object = @post_tag
    @cama_visited_tag = @post_tag
    @posts = @post_tag.the_posts.paginate(:page => params[:page], :per_page => current_site.front_per_page).eager_load(:metas)
    r_file = lookup_context.template_exists?("post_types/#{@post_type.the_slug}/post_tag") ? "post_types/#{@post_type.the_slug}/post_tag" : 'post_tag'
    layout_ = lookup_context.template_exists?("layouts/post_tag") ? "post_tag" : nil
    r = {post_tag: @post_tag, layout: layout_, render: r_file}; hooks_run("on_render_post_tag", r)
    render r[:render], (!r[:layout].nil? ? {layout: r[:layout]} : {})
  end

  # search contents
  def search
    breadcrumb_add(ct("search"))
    items = params[:post_type_slugs].present? ? current_site.the_posts(params[:post_type_slugs].split(',')) : current_site.the_posts
    @cama_visited_search = true
    @param_search = params[:q]
    layout_ = lookup_context.template_exists?("layouts/search") ? "search" : nil
    r = {layout: layout_, render: "search", posts: nil}; hooks_run("on_render_search", r)
    params[:q] = (params[:q] || '').downcase
    @posts = r[:posts] != nil ? r[:posts] : items.where("LOWER(title) LIKE ? OR LOWER(content_filtered) LIKE ?", "%#{params[:q]}%", "%#{params[:q]}%")
    @posts_size = @posts.size
    @posts = @posts.paginate(:page => params[:page], :per_page => current_site.front_per_page)
    render r[:render], (!r[:layout].nil? ? {layout: r[:layout]} : {})
  end

  # ajax requests
  def ajax
    r = {render_file: nil, render_text: "", layout: nil }
    @cama_visited_ajax = true
    hooks_run("on_ajax", r)
    if r[:render_file]
      render r[:render_file], (!r[:layout].nil? ? {layout: r[:layout]} : {})
    else
      render inline: r[:render_text]
    end
  end

  # render a post
  def post
    if params[:draft_id].present?
      draft_render
    else
      render_post(@post || params[:slug].to_s.split("/").last, true)
    end
  end

  # render user profile
  def profile
    begin
      @user = current_site.users.find(params[:user_id]).decorate
    rescue
      return page_not_found
    end
    @object = @user
    @cama_visited_profile = true
    layout_ = lookup_context.template_exists?("layouts/profile") ? "profile" : nil
    r = {user: @user, layout: layout_, render: "profile"};  hooks_run("on_render_profile", r)
    render r[:render], (!r[:layout].nil? ? {layout: r[:layout]} : {})
  end

  private
  # render a post from draft
  def draft_render
    post_draft = current_site.posts.drafts.find(params[:draft_id])
    @object = post_draft
    if can?(:update, post_draft)
      render_post(post_draft)
    else
      page_not_found
    end
  end

  # render a post
  # post_or_slug_or_id: slug_post | id post | post object
  # from_url: true/false => true (true, permit eval hooks "on_render_post")
  def render_post(post_or_slug_or_id, from_url = false)
    if post_or_slug_or_id.is_a?(String) # slug
      @post = current_site.the_posts.find_by_slug(post_or_slug_or_id)
    elsif post_or_slug_or_id.is_a?(Integer) # id
      @post = current_site.the_posts.where(id: post_or_slug_or_id).first
    else # model
      @post = post_or_slug_or_id
    end

    unless @post.present?
      if params[:format] == 'html' || !params[:format].present?
        page_not_found()
      else
        render nothing: true, status: 404
      end
    else
      @post = @post.decorate
      @object = @post
      @cama_visited_post = @post
      @post_type = @post.the_post_type
      @comments = @post.the_comments
      @categories = @post.the_categories
      @post.increment_visits!
      home_page = @_site_options[:home_page] rescue nil
      if lookup_context.template_exists?("page_#{@post.id}")
        r_file = "page_#{@post.id}"
      elsif @post.get_template(@post_type).present? && lookup_context.template_exists?(@post.get_template(@post_type))
        r_file = @post.get_template(@post_type)
      elsif home_page.present? && @post.id.to_s == home_page
        r_file = "index"
      elsif lookup_context.template_exists?("post_types/#{@post_type.the_slug}/single")
        r_file = "post_types/#{@post_type.the_slug}/single"
      elsif lookup_context.template_exists?("#{@post_type.slug}")
        r_file = "#{@post_type.slug}"
      else
        r_file = "single"
      end

      layout_ = nil
      meta_layout = @post.get_layout(@post_type)
      layout_ = meta_layout if meta_layout.present? && lookup_context.template_exists?("layouts/#{meta_layout}")
      r = {post: @post, post_type: @post_type, layout: layout_, render: r_file}
      hooks_run("on_render_post", r) if from_url
      render r[:render], (!r[:layout].nil? ? {layout: r[:layout]} : {})
    end
  end


  # render error page
  def page_not_found()
    if @_site_options[:error_404].present? # render a custom error page
      page_404 = current_site.posts.find(@_site_options[:error_404]) rescue ""
      if page_404.present?
        page_404 = page_404.decorate
        redirect_to page_404.the_url
        return
      end
    end
    render_error(404)
  end

  # define frontend locale
  # if url hasn't a locale, then it will use default locale set on application.rb
  def init_frontent
    # preview theme initializing
    if cama_sign_in? && params[:ccc_theme_preview].present? && can?(:manage, :themes)
      @_current_theme = (current_site.themes.where(slug: params[:ccc_theme_preview]).first_or_create!.decorate)
    end

    @_site_options = current_site.options
    session[:cama_current_language] = params[:cama_set_language].to_sym if params[:cama_set_language].present?
    I18n.locale = params[:locale] || session[:cama_current_language] || current_site.get_languages.first
    return page_not_found unless current_site.get_languages.include?(I18n.locale.to_sym) # verify if this locale is available for this site

    # define render paths
    lookup_context.prefixes.delete("frontend")
    lookup_context.prefixes.delete("application")
    lookup_context.prefixes.delete("camaleon_cms/frontend")
    lookup_context.prefixes.delete("camaleon_cms/camaleon")
    lookup_context.prefixes.delete("camaleon_cms/apps/plugins_front")
    lookup_context.prefixes.delete("camaleon_cms/apps/themes_front")
    lookup_context.prefixes.delete_if{|t| t =~ /themes\/(.*)\/views/i || t == "camaleon_cms/default_theme" || t == "themes/#{current_site.id}/views" }

    lookup_context.prefixes.append("themes/#{current_site.id}/views") if Dir.exist?(Rails.root.join('app', 'apps', 'themes', current_site.id.to_s).to_s)
    lookup_context.prefixes.append("themes/#{current_theme.slug}/views")
    lookup_context.prefixes.append("camaleon_cms/default_theme")

    lookup_context.prefixes = lookup_context.prefixes.uniq
    lookup_context.use_camaleon_partial_prefixes = true
    theme_init()
  end

  # initialize hooks before to execute action
  def before_hooks
    hooks_run("front_before_load")
  end

  # initialize hooks after executed action
  def after_hooks
    hooks_run("front_after_load")
  end

  # define default options for url helpers
  # control for default locale
  def default_url_options(options = {})
    begin
      if current_site.get_languages.first.to_s == I18n.locale.to_s
        options
      else
        { locale: I18n.locale }.merge options
      end
    rescue
      options
    end
  end
end
