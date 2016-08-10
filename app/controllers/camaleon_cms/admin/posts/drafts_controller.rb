=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class CamaleonCms::Admin::Posts::DraftsController < CamaleonCms::Admin::PostsController
  before_action :set_post_data_params, only: [:create, :update]

  def index
    render json: @post_type
  end

  def create
    if params[:post_id].present?
      @post_draft = CamaleonCms::Post.drafts.where(post_parent: params[:post_id]).first
      if @post_draft.present?
        @post_draft.set_option('draft_status', @post_draft.status)
        @post_draft.attributes = @post_data
      end
    end
    @post_draft = @post_type.posts.new(@post_data) unless @post_draft.present?
    r = {post: @post_draft, post_type: @post_type}; hooks_run("create_post_draft", r)
    if @post_draft.save(:validate => false)
      @post_draft.set_params(params[:meta], params[:field_options], @post_data[:keywords])
      msg = {draft: {id: @post_draft.id}, _drafts_path: cama_admin_post_type_draft_path(@post_type.id, @post_draft)}
      r = {post: @post_draft, post_type: ""}; hooks_run("created_post_draft", r)
    else
      msg = {error: @post_draft.errors.full_messages}
    end

    render json: msg
  end

  def update
    @post_draft = CamaleonCms::Post.drafts.find(params[:id])
    @post_draft.attributes = @post_data
    r = {post: @post_draft, post_type: @post_type}; hooks_run("update_post", r)
    if @post_draft.save(validate: false)
      @post_draft.set_params(params[:meta], params[:field_options], params[:options])
      hooks_run("updated_post_draft", {post: @post_draft, post_type: ""})
      msg = {draft: {id: @post_draft.id}}
    else
      msg = {error: @post_draft.errors.full_messages}
    end
    render json: msg
  end

  def destroy
  end

  private
  def set_post_data_params
    post_data = params.require(:post).permit!
    post_data[:status] = 'draft'
    post_data[:post_parent] = params[:post_id]
    post_data[:user_id] = cama_current_user.id unless post_data[:user_id].present?
    post_data[:data_tags] = params[:tags].to_s
    post_data[:data_categories] = params[:categories] || []
    @post_data = post_data
  end
end
