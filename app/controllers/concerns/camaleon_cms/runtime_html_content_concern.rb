# rubocop:disable Rails/OutputSafety
module CamaleonCms
  module RuntimeHtmlContentConcern
    extend ActiveSupport::Concern

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
  end
end
# rubocop:enable Rails/OutputSafety
