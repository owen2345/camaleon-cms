=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class FrontendController < CamaleonController
  include FrontendConcern
  prepend_before_action :init_frontent
  prepend_before_action :site_check_existence
  include Frontend::ApplicationHelper
  layout "layouts/index"
  before_action :before_hooks
  after_action :after_hooks
  # rescue_from ActiveRecord::RecordNotFound, with: :page_not_found

  def index
    init_seo(current_site)
    r = {layout: (self.send :_layout), render: "nil", custom: false}; hooks_run("on_render_index", r)
    if r[:custom]
      render r[:render], layout: r[:layout]
    else
      if @_site_options[:home_page].present?
        render_post(@_site_options[:home_page].to_i)
      else
        render "index"
      end
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
    init_seo(@category)
    @children = @category.children.no_empty.decorate
    @posts = @category.the_posts.paginate(:page => params[:page], :per_page => current_site.front_per_page).eager_load(:metas)
    r = {category: @category, layout: (self.send :_layout), render: "category"}; hooks_run("on_render_category", r)
    render r[:render], layout: r[:layout]
  end

  # render contents from post type
  def post_type
    begin
      @post_type = current_site.post_types.find(params[:post_type_id]).decorate
    rescue
      return page_not_found
    end
    init_seo(@post_type)
    @posts = @post_type.the_posts.paginate(:page => params[:page], :per_page => current_site.front_per_page).eager_load(:metas)
    @categories = @post_type.categories.no_empty.eager_load(:metas).decorate
    @post_tags = @post_type.post_tags.eager_load(:metas)
    r = {post_type: @post_type, layout: (self.send :_layout), render: "post_type"};  hooks_run("on_render_post_type", r)
    render r[:render], layout: r[:layout]
  end

  # render contents for the post tag
  def post_tag
    begin
      @post_tag = current_site.post_tags.find(params[:post_tag_id]).decorate
      @post_type = @post_tag.the_post_type
    rescue
      return page_not_found
    end
    init_seo(@post_tag)
    @posts = @post_tag.the_posts.paginate(:page => params[:page], :per_page => current_site.front_per_page).eager_load(:metas)
    r = {post_tag: @post_tag, layout: (self.send :_layout), render: "post_tag"}; hooks_run("on_render_post_tag", r)
    render r[:render], layout: r[:layout]
  end

  # search contents
  def search
    breadcrumb_add(ct("search"))
    @posts = current_site.the_posts
    @posts = params[:q].present? ? @posts.where("title LIKE ? OR content_filtered LIKE ?", "%#{params[:q]}%", "%#{params[:q]}%") : @posts.where("1=0")
    @posts_size = @posts.size
    @posts = @posts.paginate(:page => params[:page], :per_page => current_site.front_per_page)
    r = {layout: (self.send :_layout), render: "search"}; hooks_run("on_render_search", r)
    render r[:render], layout: r[:layout]
  end

  # ajax requests
  def ajax
    r = {render_file: nil, render_text: "", layout: (self.send :_layout) }
    hooks_run("on_ajax", r)
    if r[:render_file]
      render r[:render_file], layout: r[:layout]
    else
      render inline: r[:render_text]
    end
  end

  # render a post
  def post
    if params[:draft_id].present?
      draft_render
    else
      render_post(@post || params[:slug].to_s, true)
    end
  end

  # render user profile
  def profile
    begin
      @user = current_site.users.find(params[:user_id]).decorate
    rescue
      return page_not_found
    end
    init_seo(@user)
    r = {user: @user, layout: (self.send :_layout), render: "profile"};  hooks_run("on_render_profile", r)
    render r[:render], layout: r[:layout]
  end

  private
  # render a post from draft
  def draft_render
    post_draft = current_site.posts.drafts.find(params[:draft_id])
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
      page_not_found()
    else
      @post = @post.decorate
      init_seo(@post)
      @post_type = @post.the_post_type
      @comments = @post.the_comments
      @categories = @post.the_categories
      home_page = @_site_options[:home_page] rescue nil
      r_file = ""
      if lookup_context.template_exists?("page_#{@post.id}")
        r_file = "page_#{@post.id}"
      elsif @post.template.present? && lookup_context.template_exists?(@post.template)
        r_file = @post.template
      elsif @post.default_template.present? && lookup_context.template_exists?(@post.default_template)
        r_file = @post.default_template
      elsif home_page.present? && @post.id.to_s == home_page
        r_file = "index"
      elsif lookup_context.template_exists?("#{@post_type.slug}")
        r_file = "#{@post_type.slug}"
      elsif lookup_context.template_exists?("single")
        r_file = "single"
      else
        r_file = "post"
      end

      r = {post: @post, post_type: @post_type, layout: (self.send :_layout), render: r_file}
      hooks_run("on_render_post", r) if from_url
      render r[:render], layout: r[:layout]
    end
  end


  # render error page
  def page_not_found()
    if @_site_options[:error_404].present? # render a custom error page
      page_404 = current_site.posts.find(@_site_options[:error_404]) rescue ""
      if page_404.present?
        page_404 = page_404.decorate
        redirect_to page_404.the_link
        return
      end
    end
    render_error(404)
  end

  # define frontend locale
  # if url hasn't a locale, then it will use default locale set on application.rb
  def init_frontent
    # preview theme initializing
    if signin? && params[:ccc_theme_preview].present? && request.referrer.include?("preview?ccc_theme_preview=") && can?(:manager, :themes)
      @_current_theme = (current_site.themes.where(slug: params[:ccc_theme_preview]).first_or_create!.decorate)
    end

    @_site_options = current_site.options
    I18n.locale = params[:locale] || current_site.get_languages.first
    return page_not_found unless current_site.get_languages.include?(I18n.locale.to_sym) # verify if this locale is available for this site
    lookup_context.prefixes.delete("frontend")
    lookup_context.prefixes.delete("application")

    if params[:controller] == "frontend"
      lookup_context.prefixes.prepend("") unless lookup_context.prefixes.include?("")
    elsif params[:controller].start_with?("themes/")
      lookup_context.prefixes.delete(params[:controller])
      lookup_context.prefixes.prepend(params[:controller].sub("themes/#{current_theme.slug}/", ""))
    end
    theme_init()
  end

  def before_hooks
    @current_ability ||= Ability.new(current_user, current_site)
    hooks_run("front_before_load")
  end

  def after_hooks
    hooks_run("front_after_load")
  end

  # define default options for url helpers
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
