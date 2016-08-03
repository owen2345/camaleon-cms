class CamaleonCms::Admin::InstallersController < CamaleonCms::CamaleonController
  skip_before_action :cama_site_check_existence
  skip_before_action :cama_before_actions
  skip_after_action :cama_after_actions
  before_action :installer_verification, except: :welcome
  layout "camaleon_cms/login"

  def index
    @site ||= CamaleonCms::Site.new
    @site.slug = request.original_url.to_s.parse_domain
    render "form"
  end

  def save
    @site = CamaleonCms::Site.new(params[:site].permit(:slug, :name )).decorate
    if @site.save
      site_after_install(@site, params[:theme])
      flash[:notice] = t('camaleon_cms.admin.sites.message.created')
      redirect_to action: :welcome
    else
      index
    end
  end

  def welcome

  end

  def installer_verification
    redirect_to cama_root_url unless CamaleonCms::Site.count == 0
  end
end
