=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
module CamaleonCms::Frontend::ContentSelectHelper

  # select single post of post type
  # the_post_type('post') do
  #   the_post('first-blog-post')
  # end 
  def the_post(slug)
    post = @object.the_post(slug)
    process_in_block(post) do
      yield(post) if block_given?
    end
    post
  end

  # select posts of post type
  # the_post_type('post') do
  #   the_posts
  # end
  #
  # the_post_type('post') do
  #   the_posts(limit: 10)
  # end
  def the_posts(options={})
    @object.posts.visible_frontend.limit(options[:limit]).decorate
  end

  # select post type by just pass slug to parameter
  # Example: 
  # the_post_type('post')
  # the_post_type('page')
  #
  # the_post_type('post') do
  #   the_post('first-blog')
  # end
  def the_post_type(slug)
    post_type = current_site.the_post_type(slug)
    process_in_block(post_type) do
      yield(post_type) if block_given?
    end
    post_type
  end

  # select comments of post
  # the_post('blog')
  #   the_comments
  # end
  def the_comments(options={})
    @object.comments.limit(options[:limit]).decorate if @object.present?
  end

  # select title of post
  # the_post('blog') do
  #   the_title
  # end
  def the_title
    @object.the_title if @object.present?
  end

  # select content of post
  # the_post('blog') do
  #   the_content
  # end
  def the_content
    @object.the_content.html_safe if @object.present?
  end

  # select url of post
  # the_post('blog') do
  #   the_url
  # end
  def the_url
    @object.the_url if @object.present?
  end

  # select thumbnail of post
  # the_post('blog') do
  #   the_thumbnail
  # end
  def the_thumbnail
    @object.the_thumb_url if @object.present?
  end

  # select slug of post, post type ... (@object)
  # the_post('blog') do
  #   the_slug
  # end
  def the_slug
    @object.the_slug if @object.present?
  end

  # select excerpt of post
  # the_post('blog') do
  #   the_excerpt
  # end
  def the_excerpt(chars=200)
    @object.the_excerpt(chars) if @object.present?
  end

  # select custome field from object
  # the_post('blog') do
  #   the_field('extra-content')
  # end
  def the_field(slug)
    @object.the_field(slug) if @object.present?
  end

  # loop through each post of post type
  # each_post_of('post') do
  #   the_title
  # end
  #
  # each_post_of('post', limit: 10) do
  #   the_title
  # end
  def each_post_of(post_type_slug, options={})
    the_post_type(post_type_slug) do
      the_posts(options).each do |post|
        process_in_block(post) do
          yield(post) if block_given?
        end
      end
    end
  end

  # loop through each category of post type
  # each_category_of('post') do
  #   the_title
  # end
  #
  # each_category_of('post', limit: 4) do
  #   the_title
  # end
  def each_category_of(post_type_slug, options={})
    the_post_type(post_type_slug) do
      the_categories(options).each do |category|
        process_in_block(category) do
          yield(category) if block_given?
        end
      end
    end
  end

  # allow object to be global varaible in block
  # work_in_block_of(post) do
  #   the_field('extra-content')
  # end
  def process_in_block(object)
    temp_object = @object
    @object     = object
    yield
    @object     = temp_object
  end
end