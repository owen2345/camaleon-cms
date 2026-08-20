module CamaleonCms
  # Wires per-request site/theme resolution and Camaleon's before-action
  # housekeeping into the runtime controller stack. The `current_site` /
  # `current_theme` implementations live in `CamaleonCms::SiteHelper` (single
  # source of truth shared with views); this concern only adds controller-only
  # hooks like view-path setup and site-existence guards.
  module RequestContextConcern
    extend ActiveSupport::Concern

    include CamaleonCms::SiteHelper

    # Back-compat: expose the resolved site as the `@current_site` controller
    # ivar for legacy templates/plugins. The helper logic itself stays ivar-free
    # (it reads/writes `CurrentRequest.site`); only this controller concern
    # bridges the value into an instance variable so views/plugins keep working.
    def current_site(site = nil)
      result = super
      @current_site = CurrentRequest.site
      result
    end

    private

    def configure_runtime_request_context
      sanitize_forwarded_host_header
      configure_runtime_view_paths
      sync_runtime_defaults
      assign_template_compatibility_state
    end

    def sanitize_forwarded_host_header
      request.env.except!('HTTP_X_FORWARDED_HOST') if request.env['HTTP_X_FORWARDED_HOST']
    end

    def configure_runtime_view_paths
      views_dir = 'app/apps/'
      prepend_view_path(CamaleonCms::Engine.root.join(views_dir).to_s)
      prepend_view_path(Rails.root.join(views_dir).to_s)
    end

    def sync_runtime_defaults
      CamaleonCms::PostDefault.current_user = cama_current_user
      CamaleonCms::PostDefault.current_site = current_site
    end

    def assign_template_compatibility_state
      @current_site = current_site
    end

    # check if current site exist, if not, this will be redirected to main domain
    # Also, check current site status
    def cama_site_check_existence
      if current_site.blank?
        redirect_when_site_missing
      elsif (cama_current_user.present? && !cama_current_user.admin?) || cama_current_user.blank?
        handle_inactive_site_access
        handle_maintenance_site_access
      end
    end

    def redirect_when_site_missing
      if Cama::Site.main_site.present?
        url = Cama::Site.main_site.decorate.the_url
        # TODO: Remove this condition when Rails 6.x won't be supported
        if Rails.gem_version >= Gem::Version.new('7.0.0')
          redirect_to url, allow_other_host: true
        else
          redirect_to url
        end
      else
        redirect_to cama_admin_installers_path
      end
    end

    def handle_inactive_site_access
      return unless current_site.is_inactive?

      if request.original_url.to_s.match?(%r{\A#{current_site.the_url}admin(/|\z)})
        if cama_current_user.present?
          cama_logout_user
          flash[:error] = 'Site is Inactive'
        end
      else
        post = current_site.posts.find_by(id: current_site.get_option('page_inactive')).try(:decorate)
        if post
          redirect_to(post.the_url) unless params == {
            'controller' => 'camaleon_cms/frontend',
            'action' => 'post',
            'slug' => post.the_slug
          }
        else
          render html: 'This site was inactivated. Please contact to administrator.'
        end
      end
    end

    def handle_maintenance_site_access
      return unless current_site.is_maintenance?
      return if current_site.get_option('maintenance_ips', '').split(',').include?(request.remote_ip)

      post = current_site.posts.find_by(id: current_site.get_option('page_maintenance')).try(:decorate)
      if post
        redirect_to(post.the_url) if params != {
          'controller' => 'camaleon_cms/frontend',
          'action' => 'post',
          'slug' => post.the_slug
        }
      else
        render html: 'This site is in maintenance mode. Please contact to administrator.'
      end
    end
  end
end
