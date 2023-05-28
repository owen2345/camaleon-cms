require 'will_paginate/array'
module CamaleonCms
  module Admin
    class MediaController < CamaleonCms::AdminController
      skip_before_action :admin_logged_actions, except: %i[index download_private_file], raise: false
      skip_before_action :verify_authenticity_token, only: :upload, raise: false
      before_action :init_media_vars, except: :download_private_file

      # render media section
      def index
        authorize! :manage, :media
        @show_file_actions = true
        @files = @tree.paginate(page: params[:page], per_page: 100)
        @next_page = @files.current_page < @files.total_pages ? @files.current_page + 1 : nil
        add_breadcrumb I18n.t('camaleon_cms.admin.sidebar.media')
      end

      # crop a image to save as a new file
      def crop
        path_image = cama_tmp_upload(params[:cp_img_path])[:file_path]
        crop_path = cama_crop_image(path_image, params[:ic_w], params[:ic_h], params[:ic_x], params[:ic_y])
        res = upload_file(crop_path, { remove_source: true })
        CamaleonCms::User.find(params[:saved_avatar]).set_meta('avatar', res['url']) if params[:saved_avatar].present?
        render html: res['url'].html_safe
      end

      # download private files
      def download_private_file
        cama_uploader.enable_private_mode!

        file = cama_uploader.fetch_file("private/#{params[:file]}")

        send_file file, disposition: 'inline'
      end

      # render media for modal content
      def ajax
        @show_file_actions = true if current_site.get_option('file_actions_in_modals') == 'yes'
        @tree = cama_uploader.search(params[:search]) if params[:search].present?
        @files = @tree.paginate(page: params[:page], per_page: 100)
        @next_page = @files.current_page < @files.total_pages ? @files.current_page + 1 : nil
        if params[:partial].present?
          render json: { next_page: @next_page,
                         html: render_to_string(partial: 'render_file_item', locals: { files: @files }) }
        else
          render 'index', layout: false unless params[:partial].present?
        end
      end

      # do background actions in fog
      def actions
        authorize! :manage, :media if params[:media_action] != 'crop_url'
        params[:folder] = params[:folder].gsub('//', '/') if params[:folder].present?
        case params[:media_action]
        when 'new_folder'
          params[:folder] = slugify_folder(params[:folder])
          render partial: 'render_file_item', locals: { files: [cama_uploader.add_folder(params[:folder])] }
        when 'del_folder'
          cama_uploader.delete_folder(params[:folder])
          render plain: ''
        when 'del_file'
          cama_uploader.delete_file(params[:folder].gsub('//', '/'))
          render plain: ''
        when 'crop_url'
          user_url = params[:url].to_s
          user_url = "#{current_site.the_url(locale: nil)}#{user_url}" unless user_url.start_with?('data:', 'http')
          url_validation_result = UserUrlValidator.validate(user_url)
          r = if url_validation_result.is_a?(Array)
                { error: url_validation_result.join(', ') }
              else
                cama_tmp_upload(user_url, formats: params[:formats], name: params[:name])
              end
          if r[:error].present?
            render plain: helpers.sanitize(r[:error])
          else
            params[:file_upload] = r[:file_path]
            sett = { remove_source: true }
            sett[:same_name] = true if params[:same_name].present?
            sett[:name] = params[:name] if params[:name].present?
            upload(sett)
          end
        end
      end

      # upload files from media uploader
      def upload(settings = {})
        params[:dimension] = nil if params[:skip_auto_crop].present?
        f = { error: 'File not found.' }
        if params[:file_upload].present?
          f = upload_file(params[:file_upload],
                          { folder: params[:folder], dimension: params['dimension'], formats: params[:formats], versions: params[:versions],
                            thumb_size: params[:thumb_size] }.merge(settings))
        end

        if f[:error].present?
          render plain: helpers.sanitize(f[:error])
        else
          render partial: 'render_file_item', locals: { files: [f] }
        end
      end

      private

      # init basic media variables
      def init_media_vars
        # @cama_uploader = CamaleonCmsLocalUploader.new({current_site: current_site, private: true})

        cama_uploader.enable_private_mode! if params[:private].present?

        cama_uploader.clear_cache if params[:cama_media_reload] == 'clear_cache'
        cama_uploader.reload if params[:cama_media_reload] == 'reload'
        @media_formats = (params[:media_formats] || '').sub('media', ',video,audio').sub('all', '').split(',')
        @tree = cama_uploader.objects(@folder = params[:folder] || '/')
        @show_file_actions ||= params[:actions].to_s == 'true'
      end
    end
  end
end
