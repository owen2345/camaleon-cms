require 'net/http'
require 'tempfile'

# rubocop:disable Metrics/AbcSize, Metrics/ModuleLength, Naming/MethodParameterName, Rails/OutputSafety, Style/GlobalVars

module CamaleonCms
  module RuntimeStateConcern
    extend ActiveSupport::Concern
    include CamaleonCms::RuntimeShortcodeThemeConcern

    delegate :tag, :content_tag, :safe_join, :image_tag, :link_to, :sanitize, to: :helpers

    UNSAFE_EVENT_PATTERNS = %w[
      onabort onafter onbefore onblur oncanplay onchange onclick oncontextmenu oncopy oncuechange oncut ondblclick
      ondrag ondrop ondurationchange onended onerror onfocus onhashchange oninvalid oninput onkey onload onmessage
      onmouse ononline onoffline onpagehide onpageshow onpage onpaste onpause onplay onpopstate onprogress
      onpropertychange onratechange onreadystatechange onreset onresize onscroll onsearch onseek onselect onshow
      onstalled onstorage onsuspend ontimeupdate ontoggle onunloadonsubmit onvolumechange onwaiting onwheel
    ].map { |pattern| /#{pattern}\w*\s*=/i }.freeze

    SUSPICIOUS_PATTERNS = (UNSAFE_EVENT_PATTERNS + [
      /<script[\s>]/i,
      /javascript:/i,
      /<iframe[\s>]/i,
      /<object[\s>]/i,
      /<embed[\s>]/i,
      /<base[\s>]/i,
      /data:/i
    ]).freeze

    def cama_html_helpers_init
      state = camaleon_html_helper_state
      state[:pre_assets_content] = []
      state[:assets_libraries] = {}
      state[:assets_content] = []
    end

    def cama_load_libraries(*keys)
      state = camaleon_html_helper_state
      keys.each do |key|
        library = cama_assets_libraries[key.to_sym]
        state[:assets_libraries][key.to_sym] = library if library.present?
      end
    end
    alias add_asset_library cama_load_libraries

    def append_asset_libraries(libraries)
      state = camaleon_html_helper_state
      libraries.each do |key, library|
        state[:assets_libraries][key.to_sym] = if state[:assets_libraries].include?(key)
                                                 state[:assets_libraries][key.to_sym].merge(library)
                                               else
                                                 library
                                               end
      end
    end
    alias cama_load_custom_assets append_asset_libraries

    def append_asset_content(content)
      camaleon_html_helper_state[:assets_content] << content
    end

    def append_pre_asset_content(content)
      camaleon_html_helper_state[:pre_assets_content] << content
    end

    def cama_draw_pre_asset_contents
      camaleon_html_helper_state[:pre_assets_content].join('').html_safe
    end

    def cama_draw_custom_assets
      state = camaleon_html_helper_state
      cama_html_helpers_init if state[:assets_libraries].blank?
      libs = []
      state[:assets_libraries].each_value do |assets|
        libs += assets[:css] if assets[:css].present?
      end
      stylesheets = libs.uniq
      css = helpers.stylesheet_link_tag(*stylesheets, media: 'all')

      libs = []
      state[:assets_libraries].each_value do |assets|
        libs += assets[:js] if assets[:js].present?
      end
      javascripts = libs.uniq
      js = helpers.javascript_include_tag(*javascripts)

      args = { stylesheets: stylesheets, javascripts: javascripts, js_html: js, css_html: css }
      hooks_run('draw_custom_assets', args)
      trusted_fragments = [args[:css_html], args[:js_html], *state[:assets_content]].filter_map do |fragment|
        next if fragment.blank?

        fragment.is_a?(ActiveSupport::SafeBuffer) ? fragment : fragment.to_s.html_safe
      end

      helpers.safe_join(trusted_fragments, "\n")
    end

    def cama_content_init
      state = cama_content_state
      state[:before_content] = []
      state[:after_content] = []
    end

    def theme_init
      breadcrumb_items = []
      camaleon_theme_state[:front_breadcrumb] = breadcrumb_items
    end

    def breadcrumb_add(label, url = '', prepend = false)
      breadcrumb_items = nav_menu_breadcrumb_items
      if prepend
        breadcrumb_items.unshift([label, url])
      else
        breadcrumb_items << [label, url]
      end
    end

    def cama_captcha_build(len = 5)
      img = MiniMagick::Image.open(resolve_captcha_file("captcha_#{rand(12)}.jpg"))
      text = cama_rand_str(len)
      session[:cama_captcha] = [] if session[:cama_captcha].blank?
      session[:cama_captcha] << text
      img.combine_options do |c|
        c.gravity('Center')
        c.fill('#FFFFFF')
        c.draw("text 0,5 #{text}")
        c.font(resolve_captcha_file('bumpyroad.ttf'))
        c.pointsize('30')
      end
    end

    def admin_menus_add_commons
      admin_menu_add_menu(
        'dashboard',
        { icon: 'dashboard', title: t('camaleon_cms.admin.sidebar.dashboard'), url: cama_admin_dashboard_path }
      )

      items = []
      current_site.post_types.eager_load(:metas).visible_menu.find_each do |pt|
        pt = pt.decorate
        items_i = []
        if can? :posts, pt
          items_i << { icon: 'list', title: t('camaleon_cms.admin.post_type.all').to_s,
                       url: cama_admin_post_type_posts_path(pt.id) }
        end
        if can? :create_post, pt
          items_i << { icon: 'plus', title: t('camaleon_cms.admin.post_type.add_new', type_title: pt.the_title).to_s,
                       url: new_cama_admin_post_type_post_path(pt.id) }
        end
        if pt.manage_categories? && (can? :categories, pt)
          items_i << { icon: 'folder-open', title: t('camaleon_cms.admin.post_type.categories'),
                       url: cama_admin_post_type_categories_path(pt.id) }
        end
        if pt.manage_tags? && (can? :post_tags, pt)
          items_i << { icon: 'tags', title: t('camaleon_cms.admin.post_type.tags'),
                       url: cama_admin_post_type_post_tags_path(pt.id) }
        end
        if items_i.present?
          items << { icon: pt.get_option('icon', 'copy'), title: pt.the_title, url: '', items: items_i }
        end
      end

      if items.present?
        admin_menu_add_menu(
          'content',
          {
            icon: 'database', title: t('camaleon_cms.admin.sidebar.contents'), url: '', items: items,
            datas: "data-intro='#{t('camaleon_cms.admin.intro.content')}' data-position='right' data-wait='600'"
          }
        )
      end

      if can? :manage, :media
        admin_menu_add_menu(
          'media',
          {
            icon: 'picture-o', title: t('camaleon_cms.admin.sidebar.media'), url: cama_admin_media_path,
            datas: "data-intro='#{t('camaleon_cms.admin.intro.media')}' data-position='right'"
          }
        )
      end
      if can? :manage, :comments
        admin_menu_add_menu(
          'comments',
          {
            icon: 'comments', title: t('camaleon_cms.admin.sidebar.comments'), url: cama_admin_comments_path,
            datas: "data-intro='#{t('camaleon_cms.admin.intro.comments')}' data-position='right'"
          }
        )
      end

      items = []
      if can? :manage, :themes
        items << {
          icon: 'desktop', title: t('camaleon_cms.admin.sidebar.themes'), url: cama_admin_appearances_themes_path,
          datas: "data-intro='#{t('camaleon_cms.admin.intro.themes')}' data-position='right'"
        }
      end
      if can? :manage, :widgets
        items << {
          icon: 'archive', title: t('camaleon_cms.admin.sidebar.widgets'),
          url: cama_admin_appearances_widgets_main_index_path,
          datas: "data-intro='#{t('camaleon_cms.admin.intro.widgets')}' data-position='right'"
        }
      end
      if can? :manage, :nav_menu
        intro_menus_data =
          t('camaleon_cms.admin.intro.menus', image: helpers.asset_path('camaleon_cms/admin/intro/menus.png'))
        items << {
          icon: 'list', title: t('camaleon_cms.admin.sidebar.menus'), url: cama_admin_appearances_nav_menus_path,
          datas: "data-intro='#{intro_menus_data}' data-position='right'"
        }
      end
      if can? :manage, :shortcodes
        items << {
          icon: 'code', title: t('camaleon_cms.admin.sidebar.shortcodes', default: 'Shortcodes'),
          url: cama_admin_settings_shortcodes_path,
          datas: "data-intro='#{t('camaleon_cms.admin.intro.shortcodes')}' data-position='right'"
        }
      end
      if items.present?
        admin_menu_add_menu(
          'appearance',
          {
            icon: 'paint-brush', title: t('camaleon_cms.admin.sidebar.appearance'), url: '', items: items,
            datas: "data-intro='#{t('camaleon_cms.admin.intro.appearance')}' data-position='right' data-wait='500'"
          }
        )
      end

      if can? :manage, :plugins
        plugin_count = PluginRoutes.all_plugins.count do |plugin|
          !(plugin[:domain].present? && !plugin[:domain].split(',').include?(current_site.the_slug))
        end
        admin_menu_add_menu(
          'plugins',
          {
            icon: 'plug',
            title: helpers.safe_join([
                                       t('camaleon_cms.admin.sidebar.plugins'),
                                       ' ',
                                       helpers.content_tag(:small, plugin_count, class: 'label label-primary')
                                     ]),
            url: cama_admin_plugins_path,
            datas: "data-intro='#{t('camaleon_cms.admin.intro.plugins')}' data-position='right'"
          }
        )
      end

      if can? :manage, :users
        items = []
        items << { icon: 'list', title: t('camaleon_cms.admin.users.all_users'), url: cama_admin_users_path }
        items << { icon: 'plus', title: t('camaleon_cms.admin.users.add_user'), url: new_cama_admin_user_path }
        items << { icon: 'group', title: t('camaleon_cms.admin.users.user_roles'), url: cama_admin_user_roles_path }
        admin_menu_add_menu(
          'users',
          {
            icon: 'users', title: t('camaleon_cms.admin.sidebar.users'), url: '', items: items,
            datas: "data-intro='#{t('camaleon_cms.admin.intro.users')}' data-position='right' data-wait='500'"
          }
        )
      end

      items = []
      if can? :manage, :settings
        items << {
          icon: 'desktop', title: t('camaleon_cms.admin.sidebar.general_site'),
          url: cama_admin_settings_site_path,
          datas: "data-intro='#{t('camaleon_cms.admin.intro.gral_site')}' data-position='right'"
        }
        if current_site.manage_sites?
          items << {
            icon: 'cog', title: t('camaleon_cms.admin.sidebar.sites'),
            url: cama_admin_settings_sites_path,
            datas: "data-intro='#{t('camaleon_cms.admin.intro.sites')}' data-position='right'"
          }
        end
        items << {
          icon: 'files-o', title: t('camaleon_cms.admin.sidebar.content_groups'),
          url: cama_admin_settings_post_types_path,
          datas: "data-intro='#{t('camaleon_cms.admin.intro.post_type')}' data-position='right'"
        }
        items << {
          icon: 'cog', title: t('camaleon_cms.admin.sidebar.custom_fields'),
          url: cama_admin_settings_custom_fields_path,
          datas: "data-intro='#{t('camaleon_cms.admin.intro.custom_fields')}' data-position='right'"
        }
        items << {
          icon: 'language', title: t('camaleon_cms.admin.sidebar.languages'),
          url: cama_admin_settings_languages_path,
          datas: "data-intro='#{t('camaleon_cms.admin.intro.languages')}' data-position='right'"
        }
      end

      if can? :manage, :theme_settings
        items << {
          icon: 'windows', title: t('camaleon_cms.admin.settings.theme_setting', default: 'Theme Settings'),
          url: cama_admin_settings_theme_path
        }
      end
      return if items.blank?

      admin_menu_add_menu(
        'settings',
        {
          icon: 'cogs', title: t('camaleon_cms.admin.sidebar.settings'), url: '', items: items,
          datas: "data-intro='#{t('camaleon_cms.admin.intro.settings')}' data-position='right' data-wait='500'"
        }
      )
    end

    def admin_menu_add_menu(key, menu)
      CurrentRequest.admin_menu_items ||= {}
      CurrentRequest.admin_menu_items[key] = menu
    end

    def admin_menu_append_menu_item(key, menu)
      CurrentRequest.admin_menu_items ||= {}
      return if CurrentRequest.admin_menu_items[key].blank?

      CurrentRequest.admin_menu_items[key][:items] = [] unless CurrentRequest.admin_menu_items[key].key?(:items)
      CurrentRequest.admin_menu_items[key][:items] << menu
    end

    def admin_menu_prepend_menu_item(key, menu)
      CurrentRequest.admin_menu_items ||= {}
      return if CurrentRequest.admin_menu_items[key].blank?

      CurrentRequest.admin_menu_items[key][:items] = [] unless CurrentRequest.admin_menu_items[key].key?(:items)
      CurrentRequest.admin_menu_items[key][:items] = [menu] + CurrentRequest.admin_menu_items[key][:items]
    end

    def admin_menu_insert_menu_before(key_target, key_menu, menu)
      CurrentRequest.admin_menu_items ||= {}
      res = CurrentRequest.admin_menu_items.each_with_object({}) do |(key, val), hsh|
        hsh[key_menu] = menu if key == key_target
        hsh[key] = val
      end
      CurrentRequest.admin_menu_items = res
    end

    def admin_menu_insert_menu_after(key_target, key_menu, menu)
      CurrentRequest.admin_menu_items ||= {}
      res = CurrentRequest.admin_menu_items.each_with_object({}) do |(key, val), hsh|
        hsh[key] = val
        hsh[key_menu] = menu if key == key_target
      end
      CurrentRequest.admin_menu_items = res
    end

    def cama_comments_get_common_data
      comment_data = {}
      comment_data[:user_id] = cama_current_user.id
      comment_data[:author] = cama_current_user.the_name
      comment_data[:author_email] = cama_current_user.email
      comment_data[:author_IP] = request.remote_ip.to_s
      comment_data[:approved] = 'approved'
      comment_data[:agent] = request.user_agent.force_encoding('ISO-8859-1').encode('UTF-8')
      comment_data
    end

    def upload_file(uploaded_io, settings = {})
      cached_name = uploaded_io.is_a?(ActionDispatch::Http::UploadedFile) ? uploaded_io.original_filename : nil
      return { error: 'File is empty', file: nil, size: nil } if uploaded_io.blank?

      if uploaded_io.is_a?(String) && uploaded_io.match(%r{^https?://}).present?
        tmp = cama_tmp_upload(uploaded_io)
        return tmp if tmp[:error].present?

        settings[:remove_source] = true
        uploaded_io = tmp[:file_path]
      end
      uploaded_io = File.open(uploaded_io) if uploaded_io.is_a?(String)
      if settings[:dimension].present?
        uploaded_io = File.open(cama_resize_upload(uploaded_io.path, settings[:dimension]))
      end

      return { error: 'Potentially malicious content found!' } if file_content_unsafe?(uploaded_io)

      settings[:uploaded_io] = uploaded_io
      settings = settings.to_h.symbolize_keys
      settings = {
        folder: '',
        maximum: current_site.get_option('filesystem_max_size', 100).to_f.megabytes,
        formats: '*',
        generate_thumb: true,
        temporal_time: 0,
        filename: begin
          cached_name || uploaded_io.original_filename
        rescue StandardError
          uploaded_io.path.split('/').last
        end.cama_fix_filename,
        file_size: File.size(uploaded_io.to_io),
        remove_source: false,
        same_name: false,
        versions: '',
        thumb_size: nil
      }.merge!(settings)
      hooks_run('before_upload', settings)

      return { error: 'Invalid file path' } unless cama_uploader.valid_folder_path?(settings[:folder])

      err = validate_file_format_or_error(uploaded_io.path, settings[:formats])
      return err if err

      if settings[:maximum] < settings[:file_size]
        max_size = helpers.number_to_human_size(settings[:maximum])
        return { error: "#{I18n.t('camaleon_cms.common.file_size_exceeded',
                                  default: 'File size exceeded')} (#{max_size})" }
      end
      key = File.join(settings[:folder], settings[:filename]).to_s.cama_fix_slash
      res = cama_uploader.add_file(settings[:uploaded_io], key, { same_name: settings[:same_name] })

      if res['file_type'] == 'image'
        settings[:versions].to_s.delete(' ').split(',').each do |v|
          version_path = cama_resize_upload(settings[:uploaded_io].path, v, { replace: false })
          cama_uploader.add_file(version_path, cama_uploader.version_path(res['key'], v), is_thumb: true,
                                                                                          same_name: true)
          FileUtils.rm_f(version_path)
        end
      end

      if settings[:generate_thumb] && res['thumb'].present?
        cama_uploader_generate_thumbnail(uploaded_io.path, res['key'], settings[:thumb_size],
                                         settings[:remove_source])
      end
      FileUtils.rm_f(uploaded_io.path) if settings[:remove_source] && File.exist?(uploaded_io.path)

      hooks_run('after_upload', settings)
      CamaleonCmsUploader.delete_block.call(settings, cama_uploader, key) if settings[:temporal_time] > 0

      res
    end

    def cama_uploader_generate_thumbnail(uploaded_io, key, thumb_size = nil, remove_source = false)
      w = thumb_size.present? ? thumb_size.split('x')[0] : cama_uploader.thumb[:w]
      h = thumb_size.present? ? thumb_size.split('x')[1] : cama_uploader.thumb[:h]
      uploaded_io = File.open(uploaded_io) if uploaded_io.is_a?(String)
      path_thumb = cama_resize_and_crop(uploaded_io.path, w, h)
      thumb = cama_uploader.add_file(path_thumb, cama_uploader.version_path(key).sub('.svg', '.jpg'), is_thumb: true,
                                                                                                      same_name: true)
      FileUtils.rm_f(path_thumb) if remove_source
      thumb
    end

    def uploader_verify_name(file_path)
      dir = File.dirname(file_path)
      filename = File.basename(file_path).to_s.cama_fix_filename
      files = Dir.entries(dir)
      if files.include?(filename)
        i = 1
        _filename = filename
        while files.include?(_filename)
          _filename = "#{File.basename(filename, File.extname(filename))}_#{i}#{File.extname(filename)}"
          i += 1
        end
        filename = _filename
      end
      "#{File.dirname(file_path)}/#{filename}"
    end

    def cama_file_path_to_url(file_path)
      file_path.sub(Rails.public_path.to_s, begin
        root_url
      rescue StandardError
        cama_root_url
      end)
    end

    def cama_url_to_file_path(url)
      File.join(Rails.public_path, URI(url.to_s).path)
    end

    def cama_crop_image(file_path, w = nil, h = nil, w_offset = 0, h_offset = 0, resize = false, replace = true)
      force = w.present? && h.present? && !w.include?('?') && !h.include?('?') ? '!' : ''
      img = MiniMagick::Image.open(file_path)
      w = clamp_to_image_dimension(w, img[:width])
      h = clamp_to_image_dimension(h, img[:height])
      data = { img: img, w: w, h: h, w_offset: w_offset, h_offset: h_offset, resize: resize, replace: replace }
      hooks_run('before_crop_image', data)
      data[:img].combine_options do |i|
        i.resize("#{w.presence}x#{h.presence}#{force}") if data[:resize]
        i.crop "#{w.presence}x#{h.presence}+#{w_offset}+#{h_offset}#{force}" unless data[:resize]
      end

      ext = File.extname(file_path)
      res = data[:replace] ? file_path : file_path.gsub(ext, "_crop#{ext}")
      data[:img].write res
      res
    end

    def cama_resize_and_crop(file, w, h, settings = {})
      settings = { gravity: :north_east, overwrite: true, output_name: +'' }.merge!(settings)
      img = MiniMagick::Image.open(file)
      if file.end_with? '.svg'
        img.format 'jpg'
        file.sub! '.svg', '.jpg'
        settings[:output_name]&.sub!('.svg', '.jpg')
      end
      w = clamp_to_image_dimension(w, img[:width])
      h = clamp_to_image_dimension(h, img[:height])
      w_original = img[:width].to_f
      h_original = img[:height].to_f
      w = w.to_i if w.present?
      h = h.to_i if h.present?

      if w_original * h < h_original * w
        op_resize = "#{w.to_i}x"
        w_result = w
        h_result = (h_original * w / w_original)
      else
        op_resize = "x#{h.to_i}"
        w_result = (w_original * h / h_original)
        h_result = h
      end

      w_offset, h_offset = cama_crop_offsets_by_gravity(settings[:gravity], [w_result, h_result], [w, h])
      data = { img: img, w: w, h: h, w_offset: w_offset, h_offset: h_offset, op_resize: op_resize, settings: settings }
      hooks_run('before_resize_crop', data)
      data[:img].combine_options do |i|
        i.resize(data[:op_resize])
        i.gravity(settings[:gravity])
        i.crop "#{data[:w].to_i}x#{data[:h].to_i}+#{data[:w_offset]}+#{data[:h_offset]}!"
      end

      if settings[:overwrite]
        data[:img].write(file.sub('.svg', '.jpg'))
      elsif settings[:output_name].present?
        data[:img].write(file = File.join(File.dirname(file), settings[:output_name]).to_s)
      else
        data[:img].write(file = uploader_verify_name(File.join(File.dirname(file),
                                                               "crop_#{File.basename(file.sub('.svg', '.jpg'))}")))
      end
      file
    end

    def cama_tmp_upload(uploaded_io, args = {})
      tmp_path = args[:path] || File.join(Rails.public_path, 'tmp', current_site.id.to_s).to_s
      FileUtils.mkdir_p(tmp_path)
      saved = false
      downloaded_tmp_file = nil
      if uploaded_io.is_a?(String) && uploaded_io.start_with?('data:')
        _tmp_name = args[:name]
        return { error: I18n.t('camaleon_cms.admin.media.name_required').to_s } if params[:name].blank?

        err = validate_file_format_or_error(_tmp_name, args[:formats])
        return err if err

        path = uploader_verify_name(File.join(tmp_path, _tmp_name))
        File.open(path, 'wb') { |f| f.write(Base64.decode64(uploaded_io.split(';base64,').last)) }
        uploaded_io = File.open(path)
        saved = true
      elsif uploaded_io.is_a?(String) && uploaded_io.start_with?('http://', 'https://')
        err = validate_file_format_or_error(uploaded_io, args[:formats])
        return err if err

        if uploaded_io.include?(current_site.the_url(locale: nil))
          uploaded_io = File.join(Rails.public_path, uploaded_io.sub(current_site.the_url(locale: nil), '')).to_s
        else
          remote_file = cama_download_remote_file(uploaded_io)
          return remote_file if remote_file[:error].present?

          downloaded_tmp_file = remote_file[:file]
          uploaded_io = downloaded_tmp_file
        end
        _tmp_name = if uploaded_io.is_a?(String)
                      uploaded_io.split('/').last.split('?').first
                    else
                      uploaded_io.path.split('/').last
                    end
        args[:name] = args[:name] || _tmp_name
      end
      uploaded_io = File.open(uploaded_io) if uploaded_io.is_a?(String)
      err = validate_file_format_or_error(_tmp_name || uploaded_io.path, args[:formats])
      return err if err

      actual_size = begin
        uploaded_io.size
      rescue StandardError
        File.size(uploaded_io)
      end
      if args[:maximum].present? && args[:maximum] < actual_size
        max_size = helpers.number_to_human_size(args[:maximum])
        return { error: "#{I18n.t('camaleon_cms.common.file_size_exceeded',
                                  default: 'File size exceeded')} (#{max_size})" }
      end

      name = args[:name] || uploaded_io&.original_filename || uploaded_io.path.split('/').last
      name = "#{File.basename(name, File.extname(name)).parameterize}#{File.extname(name)}"
      path ||= uploader_verify_name(File.join(tmp_path, name))
      File.open(path, 'wb') { |f| f.write(uploaded_io.read) } unless saved
      path = cama_resize_upload(path, args[:dimension]) if args[:dimension].present?
      { file_path: path, error: nil }
    ensure
      downloaded_tmp_file&.close!
    end

    def cama_resize_upload(image_path, dimension, args = {})
      if cama_uploader.class.validate_file_format(image_path, 'image') && dimension.present?
        dim_parts = dimension.split('x')
        r = { file: image_path, w: dim_parts[0], h: dim_parts[1], w_offset: 0, h_offset: 0,
              resize: !dim_parts[2] || dim_parts[2] == 'resize',
              replace: true, gravity: :north_east }.merge!(args)
        hooks_run('on_uploader_resize', r)
        image_path = if r[:w].present? && r[:h].present?
                       cama_resize_and_crop(r[:file], r[:w], r[:h], { overwrite: r[:replace], gravity: r[:gravity] })
                     else
                       cama_crop_image(r[:file], r[:w], r[:h], r[:w_offset], r[:h_offset], r[:resize], r[:replace])
                     end
      end
      image_path
    end

    def cama_uploader
      @cama_uploader ||= lambda {
        thumb = current_site.get_option('filesystem_thumb_size', '100x100').split('x')
        args = {
          server: current_site.get_option('filesystem_type', 'local').downcase,
          thumb: { w: thumb[0], h: thumb[1] },
          aws_settings: {
            region: current_site.get_option('filesystem_region', 'us-west-2'),
            access_key: current_site.get_option('filesystem_s3_access_key'),
            secret_key: current_site.get_option('filesystem_s3_secret_key'),
            bucket: current_site.get_option('filesystem_s3_bucket_name'),
            cloud_front: current_site.get_option('filesystem_s3_cloudfront'),
            aws_file_upload_settings: ->(settings) { settings },
            aws_file_read_settings: ->(data, _s3_file) { data }
          },
          custom_uploader: nil
        }
        hooks_run('on_uploader', args)
        return args[:custom_uploader] if args[:custom_uploader].present?

        base_args = { current_site: current_site, thumb: args[:thumb] }
        case args[:server]
        when 's3', 'aws'
          CamaleonCmsAwsUploader.new(base_args.merge(aws_settings: args[:aws_settings]), self)
        else
          CamaleonCmsLocalUploader.new(base_args, self)
        end
      }.call
    end

    def slugify(val)
      val.to_s.downcase.strip.tr(' ', '-').gsub(/[^\w-]/, '')
    end

    def slugify_folder(val)
      split_folder = val.split('/')
      split_folder[-1] = slugify(split_folder[-1])
      split_folder.join('/')
    end

    private

    def camaleon_html_helper_state
      state = CurrentRequest.html_helper_state ||= {}
      state[:pre_assets_content] ||= []
      state[:assets_libraries] ||= {}
      state[:assets_content] ||= []
      state
    end

    def cama_assets_libraries
      state = camaleon_html_helper_state
      return state[:cama_assets_libraries] if state[:cama_assets_libraries].present?

      libs = {}
      libs[:colorpicker] =
        { js: ['camaleon_cms/admin/bootstrap-colorpicker'], css: ['camaleon_cms/admin/colorpicker'] }
      libs[:datepicker] = { js: [] }
      libs[:datetimepicker] = { js: [], css: [] }
      libs[:tinymce] =
        { js: %w[camaleon_cms/admin/tinymce/tinymce.min camaleon_cms/admin/tinymce/plugins/filemanager/plugin.min],
          css: ['camaleon_cms/admin/tinymce/skins/lightgray/content.min'] }
      libs[:form_ajax] = { js: ['camaleon_cms/admin/form/jquery.form'] }
      libs[:cropper] = {}
      libs[:post] =
        { js: %w[camaleon_cms/admin/jquery.tagsinput.min camaleon_cms/admin/post],
          css: ['camaleon_cms/admin/jquery.tagsinput'] }
      libs[:multiselect] = { js: ['camaleon_cms/admin/bootstrap-select.js'] }
      libs[:validate] = { js: ['camaleon_cms/admin/jquery.validate'] }
      libs[:nav_menu] =
        { css: ['camaleon_cms/admin/nestable/jquery.nestable'],
          js: %w[camaleon_cms/admin/jquery.nestable camaleon_cms/admin/nav_menu] }
      libs[:admin_intro] =
        { js: ['camaleon_cms/admin/introjs/intro.min'], css: ['camaleon_cms/admin/introjs/introjs.min'] }
      state[:cama_assets_libraries] = libs
    end

    def cama_content_state
      CurrentRequest.content_helper_state ||= { before_content: [], after_content: [] }
    end

    def camaleon_theme_state
      CurrentRequest.theme_helper_state ||= {}
    end

    def nav_menu_breadcrumb_items
      camaleon_theme_state[:front_breadcrumb] ||= []
    end

    def resolve_captcha_file(filename)
      base_dir = $camaleon_engine_dir.presence || Rails.root.to_s
      File.join(base_dir, 'lib', 'captcha', filename)
    end

    def cama_rand_str(len = 6)
      alphabets = [('A'..'Z').to_a].flatten!
      alphanumerics = [('A'..'Z').to_a, ('1'..'9').to_a].flatten!
      str = alphabets[rand(alphabets.size)]
      (len.to_i - 1).times do
        str << alphanumerics[rand(alphanumerics.size)]
      end
      str
    end

    def cama_download_remote_file(url)
      validation_result = UserUrlValidator.validate(url)
      return { error: validation_result.join(', ') } if validation_result.is_a?(Array)

      uri = URI.parse(url)
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
        http.open_timeout = 10
        http.read_timeout = 10
        http.request(Net::HTTP::Get.new(uri.request_uri.presence || '/'))
      end

      return { error: 'Redirects are not allowed for remote uploads.' } if response.is_a?(Net::HTTPRedirection)
      unless response.is_a?(Net::HTTPSuccess)
        return { error: "Unable to download remote file (HTTP #{response.code})." }
      end

      max_bytes = current_site.get_option('filesystem_max_size', 100).to_f.megabytes
      body = response.body
      if body.bytesize > max_bytes
        return { error: "Remote file too large (max #{ActiveSupport::NumberHelper.number_to_human_size(max_bytes)})." }
      end

      ext = File.extname(uri.path.to_s)
      tempfile = Tempfile.new(['cama-upload-url', ext], binmode: true)
      tempfile.write(body)
      tempfile.rewind
      { file: tempfile, error: nil }
    rescue StandardError => e
      { error: "Unable to download remote file: #{ERB::Util.html_escape(e.message)}" }
    end

    def file_content_unsafe?(uploaded_io)
      file = uploaded_io.is_a?(ActionDispatch::Http::UploadedFile) ? uploaded_io.tempfile : uploaded_io
      file_content_unsafe = nil

      file.set_encoding(Encoding::BINARY) if file.respond_to?(:binmode) && file.respond_to?(:set_encoding)

      file_content = file.read
      file.rewind if file.respond_to?(:rewind)
      SUSPICIOUS_PATTERNS.each do |pattern|
        if file_content&.match?(pattern)
          Rails.logger.info { "Potentially malicious content found: #{pattern.inspect}" }
          break file_content_unsafe = pattern.inspect
        end
      end

      file_content_unsafe
    end

    def cama_crop_offsets_by_gravity(gravity, original_dimensions, cropped_dimensions)
      original_width, original_height = original_dimensions
      cropped_width, cropped_height = cropped_dimensions

      vertical_offset = case gravity
                        when :north_west, :north, :north_east then 0
                        when :center, :east, :west then [((original_height - cropped_height) / 2.0).to_i, 0].max
                        when :south_west, :south, :south_east then (original_height - cropped_height).to_i
                        end

      horizontal_offset = case gravity
                          when :north_west, :west, :south_west then 0
                          when :center, :north, :south then [((original_width - cropped_width) / 2.0).to_i, 0].max
                          when :north_east, :east, :south_east then (original_width - cropped_width).to_i
                          end

      [horizontal_offset, vertical_offset]
    end

    def clamp_to_image_dimension(value, img_size)
      return value unless value.present? && value.to_s.include?('?')

      img_size.to_f > value.sub('?', '').to_i ? value.sub('?', '') : img_size
    end

    def validate_file_format_or_error(file, formats)
      return if cama_uploader.class.validate_file_format(file, formats)

      { error: "#{I18n.t('camaleon_cms.common.file_format_error')} (#{formats})" }
    end
  end
end

# rubocop:enable Metrics/AbcSize, Metrics/ModuleLength, Naming/MethodParameterName, Rails/OutputSafety, Style/GlobalVars
