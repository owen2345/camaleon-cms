class Admin::InstallersController < ApplicationController
  skip_before_action :site_check_existence
  skip_before_action :before_actions
  skip_after_action :after_actions
  before_action :installer_verification, except: :welcome
  layout "admin/installer"

  def index
    @site ||= Site.new
    @site.slug = request.original_url.to_s.parse_domain
    render "form"
  end

  def save
    @site = Site.new(params[:site].permit(:slug, :name ))
    if @site.save
      site_after_install(@site, params[:theme])
      flash[:notice] = t('admin.sites.message.created')
      redirect_to welcome_admin_installers_url
    else
      index
    end
  end

  def welcome

  end

  def installer_verification
    redirect_to root_url unless Site.count == 0
  end
end