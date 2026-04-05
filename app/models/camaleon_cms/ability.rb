module CamaleonCms
  class Ability
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
        # conditions:
        # Fetch the role record fresh from the database for the current site to
        # ensure up-to-date role meta (avoid stale cached role objects during
        # tests or runtime meta updates).
        current_user_role = if current_site.present?
                              current_site.user_roles.where(slug: user.role).first
                            else
                              user.get_role(current_site)
                            end || current_site.user_roles.new
        @roles_manager = current_user_role.get_meta("_manager_#{current_site.id}", {}) || {}
        @roles_post_type = current_user_role.get_meta("_post_type_#{current_site.id}", {}) || {}

        ids_publish = @roles_post_type[:publish] || []
        ids_edit = @roles_post_type[:edit] || []
        ids_edit_other = @roles_post_type[:edit_other] || []
        ids_edit_publish = @roles_post_type[:edit_publish] || []
        ids_delete = @roles_post_type[:delete] || []
        ids_delete_other = @roles_post_type[:delete_other] || []
        ids_delete_publish = @roles_post_type[:delete_publish] || []

        safe_can :posts, CamaleonCms::PostType do |pt|
          (ids_edit + ids_edit_other + ids_edit_publish).to_i.include?(pt.id)
        end

        safe_can :create_post, CamaleonCms::PostType do |pt|
          ids_edit.to_i.include?(pt.id)
        end
        safe_can :publish_post, CamaleonCms::PostType do |pt|
          ids_publish.to_i.include?(pt.id)
        end
        safe_can :edit_other, CamaleonCms::PostType do |pt|
          ids_edit_other.to_i.include?(pt.id)
        end
        safe_can :edit_publish, CamaleonCms::PostType do |pt|
          ids_edit_publish.to_i.include?(pt.id)
        end

        safe_can :categories, CamaleonCms::PostType do |pt|
          @roles_post_type[:manage_categories].to_i.include?(pt.id)
        end
        safe_can :post_tags, CamaleonCms::PostType do |pt|
          @roles_post_type[:manage_tags].to_i.include?(pt.id)
        end

        safe_can :update, CamaleonCms::Post do |post|
          pt_id = post.post_type.id
          r = false
          r ||= ids_edit.to_i.include?(pt_id) && post.user_id == user.id
          r ||= ids_edit_publish.to_i.include?(pt_id) && post.published?
          r ||= ids_edit_other.to_i.include?(pt_id) && post.user_id != user.id
          r
        end

        safe_can :destroy, CamaleonCms::Post do |post|
          pt_id = post.post_type.id
          r = false
          r ||= ids_delete.to_i.include?(pt_id) && post.user_id == user.id
          r ||= ids_delete_publish.to_i.include?(pt_id) && post.published?
          r ||= ids_delete_other.to_i.include?(pt_id) && post.user_id != user.id
          r
        end

        # support for custom abilities for each posttype
        # sample: https://camaleon.website/documentation/category/40756-uncategorized/custom-models.html
        @roles_post_type.each do |k, v|
          next if %w[edit edit_other edit_publish publish manage_categories].include?(k.to_s)

          safe_can k.to_sym, CamaleonCms::PostType do |pt|
            v.include?(pt.id.to_s)
          end
        end

        # others
        %i[media comments themes widgets nav_menu plugins users settings custom_fields select_eval].each do |manager_key|
          safe_can :manage, manager_key if @roles_manager[manager_key]
        end
        @roles_manager.try(:each) do |rol_manage_key, val_role|
          safe_can :manage, rol_manage_key.to_sym if val_role.to_s.cama_true?
        end
      end
      cannot :impersonate, CamaleonCms::User do |u|
        u.id == user.id
      end
    end

    # overwrite can method to support decorator class names
    def can?(action, subject, *extra_args)
      if subject.is_a?(Draper::Decorator)
        super(action, subject.model, *extra_args)
      else
        super(action, subject, *extra_args)
      end
    end

    # overwrite cannot method to support decorator class names
    def cannot?(*args)
      !can?(*args)
    end

    private

    # Wraps a can rule with block-level exception handling.
    # Blocks are evaluated later during authorization checks (can? calls), so exceptions
    # from accessing post properties, role metadata, etc. must be caught here to fail closed.
    # Non-block calls (e.g., can :manage, :symbol) do not need wrapping; can itself is safe.
    def safe_can(action, subject, &block)
      if block_given?
        can(action, subject) do |resource|
          safely_false { block.call(resource) }
        end
      else
        # No block: can(action, subject) does not evaluate user logic; safe to call directly.
        can(action, subject)
      end
    end

    # Fails closed for permission checks when role/post metadata is malformed.
    # Used by safe_can to guard block evaluation during authorization checks.
    def safely_false
      yield
    rescue StandardError
      false
    end
  end
end
