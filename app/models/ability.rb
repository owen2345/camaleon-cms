class Ability
  include CanCan::Ability

  def initialize(user, current_site = nil)
    # Define abilities for the passed in user here. For example:
    #
    user ||= User.new # guest user (not logged in)
    if user.admin?
      can :manage, :all
    elsif user.client?
      can :read, :all
    else
      #conditions:
      @roles_manager = user.get_role(current_site).meta["_manager_#{current_site.id.to_s}".to_sym] || {} rescue {}
      @roles_post_type ||= user.get_role(current_site).meta["_post_type_#{current_site.id.to_s}".to_sym] || {} rescue {}

      ids_publish = @roles_post_type[:publish] || []
      ids_edit = @roles_post_type[:edit] || []
      ids_edit_other = @roles_post_type[:edit_other] || []
      ids_edit_publish = @roles_post_type[:edit_publish] || []
      ids_delete = @roles_post_type[:delete] || []
      ids_delete_other = @roles_post_type[:delete_other] || []
      ids_delete_publish = @roles_post_type[:delete_publish] || []

      can :posts, PostType do |pt|
        (ids_edit + ids_edit_other + ids_edit_publish).to_i.include?(pt.id) rescue false
      end

      can :create_post, PostType do |pt|
        ids_edit.to_i.include?(pt.id) rescue false
      end
      can :publish_post, PostType do |pt|
        ids_publish.to_i.include?(pt.id) rescue false
      end

      can :categories, PostType do |pt|
        @roles_post_type[:manage_categories].to_i.include?(pt.id) rescue false
      end
      can :post_tags, PostType do |pt|
        @roles_post_type[:manage_tags].to_i.include?(pt.id) rescue false
      end

      can :update, Post do |post|
        pt_id = post.post_type.id
        r = false
        r ||= (ids_edit).to_i.include?(pt_id) && post.user_id == user.id rescue false
        r ||= (ids_edit_publish ).to_i.include?(pt_id) && post.published? rescue false
        r ||= (ids_edit_other).to_i.include?(pt_id) && post.user_id != user.id  rescue false
        r
      end

      can :destroy, Post do |post|
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


    end




    # variants:

    # can [:update, :destroy], [Article, Comment]

    #alias_action :create, :read, :update, :destroy, :to => :crud
    # can :crud, User

    # can :invite, User

    # can :read, Project, :priority => 1..3

    # conditions:
    # can :read, Project, :active => true, :user_id => user.id
    # can :read, Project, :category => { :visible => true }
    # can :manage, Project, :group => { :id => user.group_ids }
    # can :read, Photo, Photo.scope_defined do |photo|
    #   photo.groups.empty?
    # end




    # See the wiki for details:
    # https://github.com/CanCanCommunity/cancancan/wiki/Defining-Abilities
  end
end
