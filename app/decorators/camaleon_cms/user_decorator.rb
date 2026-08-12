module CamaleonCms
  class UserDecorator < CamaleonCms::ApplicationDecorator
    include CamaleonCms::CustomFieldsConcern
    delegate_all

    # return the identifier
    def the_username
      object.username
    end

    # return the fullname
    def the_name
      object.fullname
    end

    # return the role title of this user for current site
    def the_role
      object.get_role(h.current_site).try(:decorate).try(:the_title) || ''
    end

    # return the avatar for this user, default: assets/admin/img/no_image.jpg
    def the_avatar(default_avatar = nil)
      return object.get_meta('avatar') if avatar_exists?

      default_avatar || h.asset_url('camaleon_cms/admin/img/no_image.jpg')
    end

    # return the slogan for this user, default: Hello World
    def the_slogan
      object.get_meta('slogan', 'Hello World')
    end

    # return front url for this user
    def the_url(*args)
      args = args.extract_options!
      args[:label] = I18n.t('routes.profile', default: 'profile')
      args[:user_id] = the_id
      args[:user_name] = the_name.parameterize
      args[:user_name] = the_username if args[:user_name].blank?
      args[:locale] = get_locale unless args.include?(:locale)
      args[:format] = args[:format] || 'html'
      as_path = args.delete(:as_path)
      h.cama_url_to_fixed("cama_profile_#{as_path.present? ? 'path' : 'url'}", args)
    end

    # return the url for the profile in the admin module
    def the_admin_profile_url
      args = h.cama_current_site_host_port({})
      h.cama_admin_profile_url(object.id, args)
    end

    # return all contents created by this user in current site
    def the_contents
      h.current_site.posts.where(user_id: object.id)
    end

    # Whether this user may set another user's role. Only an admin may grant the `admin` role (the one
    # `User#admin?` tests) or change the role of a user who is already an admin — so holding
    # `:manage, :users` is neither a path to minting an admin (escalation) nor to stripping one (H10).
    def role_grantor?(other_user, new_role = nil)
      return false unless h.can?(:manage, :users) && (other_user.nil? || id != other_user.id)
      return admin? if new_role.to_s == 'admin' || other_user&.role.to_s == 'admin'

      true
    end

    # Whether this user may edit +other_user+'s login credential (password) or recovery identifiers
    # (email, username). Only an admin may edit an admin's account: a `:manage, :users` holder who could
    # reset an admin's password would sign in as them, and one who could repoint an admin's email would
    # hijack a password-reset link — either is a path to superadmin that would make `role_grantor?`'s
    # guard of the privileged set moot (H10). Editing one's own account, or any non-admin, is unrestricted
    # here; the controller's `:manage, :users` (or self) authorization still applies first.
    def may_edit_credentials?(other_user)
      return true unless other_user&.admin?

      admin?
    end

    def self.object_class_name
      'CamaleonCms::User'
    end

    private

    def avatar_exists?
      # TODO: change verification
      # if object.get_meta('avatar').present?
      #   File.exist?(h.cama_url_to_file_path(object.get_meta('avatar'))) ||
      #     Faraday.head(object.get_meta('avatar')).status == 200
      # else
      #   false
      # end
      object.get_meta('avatar').present?
    end
  end
end
