module CamaleonCms
  module Admin
    class InstallersController < CamaleonCms::CamaleonController
      skip_before_action :cama_site_check_existence
      skip_before_action :cama_before_actions
      skip_after_action :cama_after_actions
      before_action :installer_verification, except: :welcome
      before_action :require_setup_token, only: :save
      layout 'camaleon_cms/login'

      def index
        # Ensure the setup token exists (and is logged) so a remote operator can read it and enter it
        # below. Local installs are exempt (require_setup_token), so no token is generated for them.
        CamaleonCms::SetupToken.value if CamaleonCms::SetupToken.required? && !request.local?
        @site ||= CamaleonCms::Site.new
        @site.slug = request.original_url.to_s.parse_domain
        render 'form'
      end

      def save
        @site = CamaleonCms::Site.new(params[:site].permit(:slug, :name)).decorate
        if @site.save
          site_after_install(@site, params[:theme])
          CamaleonCms::SetupToken.clear! # single-use: the installer is closed now that a site exists
          # Carry the generated admin password to the welcome page for a single, session-scoped display.
          flash[:generated_admin_password] = @site.generated_admin_password
          session[:cama_installer_welcome] = true
          flash[:notice] = t('camaleon_cms.admin.sites.message.created')
          redirect_to action: :welcome
        else
          index
        end
      end

      def welcome
        # Only the operator who just completed setup may see the credentials; the marker is one-time.
        return redirect_to cama_admin_login_url unless session.delete(:cama_installer_welcome)

        @generated_admin_password = flash[:generated_admin_password]
      end

      def installer_verification
        redirect_to cama_root_url unless CamaleonCms::Site.count == 0
      end

      # Refuse to provision unless the request carries the setup token (readable only from the server's
      # environment or filesystem). Only enforced while no site exists; afterwards installer_verification
      # has already closed the installer.
      def require_setup_token
        return unless CamaleonCms::SetupToken.required?
        # Loopback requests (a local console/dev install, or an SSH tunnel) already prove host access,
        # so the token is required only for remote requests. request.local? is true only when the
        # computed client IP is loopback, so a real remote client behind a proxy that forwards
        # X-Forwarded-For is still gated. See harden-installer-default-admin.
        return if request.local?
        return if CamaleonCms::SetupToken.valid?(params[:setup_token])

        flash[:error] = t('camaleon_cms.admin.installer.invalid_setup_token',
                          default: 'A valid setup token is required to install. See the server log or ' \
                                   'tmp/camaleon_setup_token.')
        redirect_to cama_admin_installers_path
      end
    end
  end
end
