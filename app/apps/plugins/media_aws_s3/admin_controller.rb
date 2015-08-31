class Plugins::MediaAwsS3::AdminController < Apps::PluginsAdminController
  include Plugins::MediaAwsS3::MainHelper
  include ElFinderS3::Action

  skip_before_filter :authenticate, only: :img
  skip_before_filter :admin_logged_actions, except: :index
  skip_before_filter :verify_authenticity_token

  def index
    authorize! :manager, :media
  end

  def settings
    @media_aws_s3 = current_site.get_meta('media_aws_s3_config')
  end

  def save_settings
    current_site.set_meta('media_aws_s3_config', {
                                                 bucket_name: params[:media_aws_s3][:bucket_name],
                                                 region: params[:media_aws_s3][:region],
                                                 access_key_id: params[:media_aws_s3][:access_key_id],
                                                 secret_access_key: params[:media_aws_s3][:secret_access_key],
                                                 cdn_base_path: params[:media_aws_s3][:cdn_base_path]
                                               })
    flash[:notice] = "#{t('plugin.media_aws_s3.messages.settings_saved')}"
    redirect_to action: :settings
  end

  # here add your custom functions

  def elfinder
    plugin_config = current_site.get_meta('media_aws_s3_config')
    dirname = '/'
    r = {dirname: dirname}; hooks_run('elfinder', r)
    h, r = ElFinderS3::Connector.new(
      :mime_handler => ElFinderS3::MimeType,
      :root => '/',
      :url => plugin_config[:cdn_base_path],
      :thumbs => true,
      :thumbs_size => 100,
      :thumbs_directory => 'thumbs',
      :home => t('admin.media.home'),
      :original_filename_method => lambda { |file| "#{File.basename(file.original_filename, File.extname(file.original_filename)).parameterize}#{File.extname(file.original_filename)}" },
      :default_perms => {:read => true, :write => true, :rm => true, :hidden => false},
      :server => plugin_config
    ).run(params)

    headers.merge!(h)

    render (r.empty? ? {:nothing => true} : {:text => r.to_json}), :layout => false
  end

  def iframe
    render layout: true
  end

  def crop
    url_image = crop_image(params[:cp_img_path], params[:ic_w], params[:ic_h], params[:ic_x], params[:ic_y])
    if params[:saved_avatar].present?
      User.find(params[:saved_avatar]).set_meta('avatar', url_image)
    end
    render text: url_image
  end

end
