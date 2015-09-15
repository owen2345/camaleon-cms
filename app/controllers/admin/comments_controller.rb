=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class Admin::CommentsController < AdminController
  before_action :validate_role
  before_action :set_comment, only: ['show','edit','update','destroy']
  def index
    @posts = current_site.posts.no_trash.joins(:comments).select("posts.*, comments.post_id").order("comments.post_id").paginate(:page => params[:page], :per_page => current_site.admin_per_page)
  end

  def edit
    render 'form'
  end

  def responses
    @comments = current_site.posts.find(params[:post_id]).comments.main
    if params[:post_comment].present?
      comment_data = params[:post_comment]
      comment_data[:post_id] = params[:post_id]
      comment_data[:user_id] = current_user.id
      comment_data[:author] = current_user.the_name
      comment_data[:author_email] = current_user.email
      comment_data[:author_url] = ""
      comment_data[:author_IP] = request.remote_ip.to_s
      comment_data[:approved] = "approved"
      comment_data[:agent] = request.user_agent.force_encoding("ISO-8859-1").encode("UTF-8")
      @comment = @comments.new(comment_data)
      if @comment.save
        flash[:notice] = t('admin.comments.message.responses')
        redirect_to action: :responses, post_id: params[:post_id]
      else
        render 'reply'
      end
    else
      render 'reply'
    end
  end

  def update
    if @comment.update(params[:post_comment])
      # @comment.set_meta_from_form(params[:meta])
      flash[:notice] = t('admin.comments.message.updated')
      redirect_to action: :index
    else
      render 'form'
    end
  end

  def new
    @comment = PostComment.new
    render 'form'
  end

  def create
    comment_data = params[:post_comment]

    @comment = PostComment.new(comment_data)
    if @comment.save
      flash[:notice] = t('admin.comments.message.created')
      redirect_to action: :index
    else
      render 'form'
    end
  end

  def destroy
    flash[:notice] = t('admin.comments.message.destroy') if @comment.destroy

    redirect_to action: :index
  end

  def delete
    @comment_delete = PostComment.find(params[:answers_id])
    @comment_delete.destroy
    params[:notice] = t('admin.comments.message.deleted')
    render json: params
  end

  def destroy_comments
    Post.find(params[:post_id]).comments.destroy_all
    params[:notice] = t('admin.comments.message.destroy_comments')
    redirect_to action: :index
  end

  # change status comments param =  params[:answers_id]
  def change_status
    @comment_update = PostComment.find(params[:answers_id])
    @comment_update.update_column('approved', params[:approved])

    params[:notice] = t('admin.comments.message.change_status')
    render json: params
  end

  private

  def set_comment
    begin
      @comment = PostComment.find(params[:id])
    rescue
      flash[:error] = t('admin.comments.message.error')
      redirect_to admin_path
    end
  end

  def validate_role
    authorize! :manager, :comments
  end
end
