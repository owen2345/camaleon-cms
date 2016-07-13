=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class CamaleonCms::Ability
  include CanCan::Ability

  def initialize(user, current_site = nil)
    # Define abilities for the passed in user here. For example:
    #
    user ||= CamaleonCms::User.new # guest user (not logged in)
    if user.admin?
      can :manage, :all
    elsif user.client?
      can :read, :all
    else
      #conditions:
      @roles_manager = user.get_role(current_site).get_meta("_manager_#{current_site.id.to_s}", {})
      @roles_post_type ||= user.get_role(current_site).get_meta("_post_type_#{current_site.id.to_s}", {})

      ids_publish = @roles_post_type[:publish] || []
      ids_edit = @roles_post_type[:edit] || []
      ids_edit_other = @roles_post_type[:edit_other] || []
      ids_edit_publish = @roles_post_type[:edit_publish] || []
      ids_delete = @roles_post_type[:delete] || []
      ids_delete_other = @roles_post_type[:delete_other] || []
      ids_delete_publish = @roles_post_type[:delete_publish] || []

      can :posts, CamaleonCms::PostType do |pt|
        (ids_edit + ids_edit_other + ids_edit_publish).to_i.include?(pt.id) rescue false
      end

      can :create_post, CamaleonCms::PostType do |pt|
        ids_edit.to_i.include?(pt.id) rescue false
      end
      can :publish_post, CamaleonCms::PostType do |pt|
        ids_publish.to_i.include?(pt.id) rescue false
      end
      can :edit_other, CamaleonCms::PostType do |pt|
        ids_edit_other.to_i.include?(pt.id) rescue false
      end
      can :edit_publish, CamaleonCms::PostType do |pt|
        ids_edit_publish.to_i.include?(pt.id) rescue false
      end

      can :categories, CamaleonCms::PostType do |pt|
        @roles_post_type[:manage_categories].to_i.include?(pt.id) rescue false
      end
      can :post_tags, CamaleonCms::PostType do |pt|
        @roles_post_type[:manage_tags].to_i.include?(pt.id) rescue false
      end

      can :update, CamaleonCms::Post do |post|
        pt_id = post.post_type.id
        r = false
        r ||= (ids_edit).to_i.include?(pt_id) && post.user_id == user.id rescue false
        r ||= (ids_edit_publish).to_i.include?(pt_id) && post.published? rescue false
        r ||= (ids_edit_other).to_i.include?(pt_id) && post.user_id != user.id rescue false
        r
      end

      can :destroy, CamaleonCms::Post do |post|
        pt_id = post.post_type.id
        r = false
        r ||= (ids_delete).to_i.include?(pt_id) && post.user_id == user.id rescue false
        r ||= (ids_delete_publish).to_i.include?(pt_id) && post.published? rescue false
        r ||= (ids_delete_other).to_i.include?(pt_id) && post.user_id != user.id rescue false
        r
      end


      #others
      can :manage, :media     if @roles_manager[:media] rescue false
      can :manage, :comments  if @roles_manager[:comments] rescue false
      #can :manage, :forms     if @roles_manager[:forms] rescue false
      can :manage, :themes    if @roles_manager[:themes] rescue false
      can :manage, :widgets   if @roles_manager[:widgets] rescue false
      can :manage, :nav_menu  if @roles_manager[:nav_menu] rescue false
      can :manage, :plugins   if @roles_manager[:plugins] rescue false
      can :manage, :users     if @roles_manager[:users] rescue false
      can :manage, :settings  if @roles_manager[:settings] rescue false
      @roles_manager.try(:each) do |rol_manage_key, val_role|
        can :manage, rol_manage_key.to_sym if val_role.to_s.cama_true? rescue false
      end
    end
  end

  #overwrite can method to support decorator class names
  def can?(action, subject, *extra_args)
    if subject.is_a?(Draper::Decorator)
      super(action,subject.model,*extra_args)
    else
      super(action,subject,*extra_args)
    end
  end

  #overwrite cannot method to support decorator class names
  def cannot?(*args)
    !can?(*args)
  end

end
