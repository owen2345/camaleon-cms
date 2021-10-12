require 'will_paginate/array'
class CamaleonCms::Admin::MediaController < CamaleonCms::AdminController
  skip_before_action :admin_logged_actions, except: [:index, :download_private_file], raise: false
  skip_before_action :verify_authenticity_token, only: :upload, raise: false
  before_action :init_media_vars, except: :download_private_file

  LOCALHOST_DOMAIN_MATCHER = %r{
    localhost|
    127\.0\.0\.1|
    0\.0\.0\.0|
    0x7f\.0x0\.0x0\.0x1| # hex encoding
    0177\.0\.0\.01| # octal encoding
    2130706433 # dword encoding
  }x

  # render media section
  def index
    authorize! :manage, :media
    @show_file_actions = true
    @files = @tree.paginate(page: params[:page], per_page: 100)
    @next_page = @files.current_page < @files.total_pages ? @files.current_page + 1 : nil
    add_breadcrumb I18n.t("camaleon_cms.admin.sidebar.media")
  end

  # crop a image to save as a new file
  def crop
    path_image = cama_tmp_upload(params[:cp_img_path])[:file_path]
    crop_path = cama_crop_image(path_image, params[:ic_w], params[:ic_h], params[:ic_x], params[:ic_y])
    res = upload_file(crop_path, {remove_source: true})
    CamaleonCms::User.find(params[:saved_avatar]).set_meta('avatar', res["url"]) if params[:saved_avatar].present? # save current crop image as avatar
    render html: res["url"].html_safe
  end

  # download private files
  def download_private_file
    cama_uploader.enable_private_mode!

    file = cama_uploader.fetch_file("private/#{params[:file]}")

    send_file file, disposition: 'inline'

  end

  # render media for modal content
  def ajax
    if current_site.get_option('file_actions_in_modals') == 'yes'
      @show_file_actions = true
    end
    @tree = cama_uploader.search(params[:search]) if params[:search].present?
    @files = @tree.paginate(page: params[:page], per_page: 100)
    @next_page = @files.current_page < @files.total_pages ? @files.current_page + 1 : nil
    if params[:partial].present?
      render json: {next_page: @next_page, html: render_to_string(partial: "render_file_item", locals: { files: @files })}
    else
      render "index", layout: false unless params[:partial].present?
    end
  end

  # do background actions in fog
  def actions
    if params[:media_action] != 'crop_url'
      authorize! :manage, :media
    end
    params[:folder] = params[:folder].gsub("//", "/") if params[:folder].present?
    case params[:media_action]
      when "new_folder"
        params[:folder] = slugify_folder(params[:folder])
        render partial: "render_file_item", locals: {files: [cama_uploader.add_folder(params[:folder])]}
      when "del_folder"
        cama_uploader.delete_folder(params[:folder])
        render inline: ""
      when "del_file"
        cama_uploader.delete_file(params[:folder].gsub("//", "/"))
        render inline: ""
      when 'crop_url'
        unless params[:url].start_with?('data:')
          params[:url] = (params[:url].start_with?('http') ? '' : current_site.the_url(locale: nil)) + params[:url]
        end
        r = if local_url?(params[:url])
              { error: t("camaleon_cms.admin.media.local_upload_denied") }
            else
              cama_tmp_upload( params[:url], formats: params[:formats], name: params[:name])
            end
        unless r[:error].present?
          params[:file_upload] = r[:file_path]
          sett = {remove_source: true}
          sett[:same_name] = true if params[:same_name].present?
          sett[:name] = params[:name] if params[:name].present?
          upload(sett)
        else
          render inline: r[:error]
        end
    end
  end

  def local_url?(url)
    url.try :match?, LOCALHOST_DOMAIN_MATCHER
  end

  # upload files from media uploader
  def upload(settings = {})
    params[:dimension] = nil if params[:skip_auto_crop].present?
    f = {error: "File not found."}
    if params[:file_upload].present?
      f = upload_file(params[:file_upload], {folder: params[:folder], dimension: params['dimension'], formats: params[:formats], versions: params[:versions], thumb_size: params[:thumb_size]}.merge(settings))
    end
    render(partial: "render_file_item", locals:{ files: [f] }) unless f[:error].present?
    render inline: f[:error] if f[:error].present?
  end

  private

  # init basic media variables
  def init_media_vars
    # @cama_uploader = CamaleonCmsLocalUploader.new({current_site: current_site, private: true})

    cama_uploader.enable_private_mode! if params[:private].present?

    cama_uploader.clear_cache if params[:cama_media_reload] == 'clear_cache'
    cama_uploader.reload if params[:cama_media_reload] == 'reload'
    @media_formats = (params[:media_formats] || "").sub("media", ",video,audio").sub("all", "").split(",")
    @tree = cama_uploader.objects(@folder = params[:folder] || "/")
    @show_file_actions ||= params[:actions].to_s == 'true'
  end

end
