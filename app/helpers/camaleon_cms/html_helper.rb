module CamaleonCms
  module HtmlHelper
    def cama_html_helpers_init
      state = camaleon_html_helper_state
      state[:pre_assets_content] = [] # Assets contents before the libraries import
      state[:assets_libraries] = {}
      state[:assets_content] = []
    end

    # register a new asset library to be included on demand calling by: cama_load_libraries(...)
    # sample: cama_assets_library_register("my_library", {js: ["url_js", "url_js2"], css: ["url_css1", "url_css2"]})
    #   cama_load_libraries("my_library")
    def cama_assets_library_register(key, assets = {})
      key = key.to_sym
      cama_assets_libraries
      state = camaleon_html_helper_state
      state[:cama_assets_libraries][key] = { css: [], js: [] } if state[:cama_assets_libraries][key].blank?
      state[:cama_assets_libraries][key][:css] += assets[:css] if assets[:css].present?
      state[:cama_assets_libraries][key][:js] += assets[:js] if assets[:js].present?
    end

    # enable to load admin or registered libraries (colorpicker, datepicker, tinymce, form_ajax, cropper)
    # sample: add_asset_library("datepicker", "colorpicker")
    # This will add this assets library in the admin head or in a custom place by calling: cama_draw_custom_assets()
    def cama_load_libraries(*keys)
      state = camaleon_html_helper_state
      keys.each do |key|
        library = cama_assets_libraries[key.to_sym]
        state[:assets_libraries][key.to_sym] = library if library.present?
      end
    end

    alias add_asset_library cama_load_libraries

    # add custom asset libraries (js, css or both) for the current request, also you can add extra css or js files for
    # existent libraries
    # sample: (add a new library)
    #   append_asset_libraries(
    #     {
    #       "my_library_key"=> {
    #         js: [plugin_asset("js/my_js"), "plugins/myplugin/assets/js/my_js2"],
    #         css: [plugin_asset("css/my_css"), "plugins/myplugin/assets/css/my_css2"]
    #       }
    #     }
    #   )
    # sample: (update existent library)
    #   append_asset_libraries({"colorpicker"=>{js: [plugin_asset("js/my_custom_js")] } })
    # return nil
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

    # add asset content into custom assets
    # content may be: <script>alert()</script>
    # content may be: <style>a{color: red;}</style>
    # this will be printed with <%raw cama_draw_custom_assets %>
    def append_asset_content(content)
      camaleon_html_helper_state[:assets_content] << content
    end

    # add pre asset content into custom assets
    # content may be: <script>alert()</script>
    # content may be: <style>a{color: red;}</style>
    # this will be printed before assets_library with <%raw cama_draw_pre_asset_contents %>
    def append_pre_asset_content(content)
      camaleon_html_helper_state[:pre_assets_content] << content
    end

    # return all scripts to be executed before import the js libraries(cama_draw_custom_assets)
    def cama_draw_pre_asset_contents
      # rubocop:disable Rails/OutputSafety -- Callers append trusted script/style fragments that must render as markup.
      camaleon_html_helper_state[:pre_assets_content].join('').html_safe
      # rubocop:enable Rails/OutputSafety
    end

    # return all js libraries added [aa.js, bb,js, ..]
    # def get_assets_js
    def cama_draw_custom_assets
      state = camaleon_html_helper_state
      cama_html_helpers_init if state[:assets_libraries].blank?
      libs = []
      state[:assets_libraries].each_value do |assets|
        libs += assets[:css] if assets[:css].present?
      end
      stylesheets = libs.uniq
      css = stylesheet_link_tag(*stylesheets, media: 'all')

      libs = []
      state[:assets_libraries].each_value do |assets|
        libs += assets[:js] if assets[:js].present?
      end
      javascripts = libs.uniq
      js = javascript_include_tag(*javascripts)

      args = { stylesheets: stylesheets, javascripts: javascripts, js_html: js, css_html: css }
      hooks_run('draw_custom_assets', args)
      # rubocop:disable Rails/OutputSafety -- Asset helper output and appended fragments are trusted framework/plugin markup.
      trusted_fragments = [args[:css_html], args[:js_html], *state[:assets_content]].filter_map do |fragment|
        next if fragment.blank?

        fragment.is_a?(ActiveSupport::SafeBuffer) ? fragment : fragment.to_s.html_safe
      end
      # rubocop:enable Rails/OutputSafety

      safe_join(trusted_fragments, "\n")
    end

    # create an HTML tooltip to include anywhere
    # text: text of the tooltip
    # location: location of the tooltip (left | right | top |bottom)
    def cama_html_tooltip(text = 'Tooltip', location = 'left')
      tag.a(href: 'javascript:;', title: text, data: { toggle: 'tooltip', placement: location }) do
        tag.i(class: 'fa fa-info-circle')
      end
    end

    private

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
      libs[:cropper] = {} # loaded by default
      libs[:post] =
        { js: %w[camaleon_cms/admin/post],
          css: [] }
      libs[:multiselect] = { js: ['camaleon_cms/admin/bootstrap-select.js'] }
      libs[:validate] = { js: ['camaleon_cms/admin/jquery.validate'] }
      libs[:nav_menu] =
        { css: ['camaleon_cms/admin/nestable/jquery.nestable'],
          js: %w[camaleon_cms/admin/jquery.nestable camaleon_cms/admin/nav_menu] }
      libs[:admin_intro] =
        { js: ['camaleon_cms/admin/introjs/intro.min'], css: ['camaleon_cms/admin/introjs/introjs.min'] }
      state[:cama_assets_libraries] = libs
    end

    def camaleon_html_helper_state
      state = CurrentRequest.html_helper_state ||= {}
      state[:pre_assets_content] ||= []
      state[:assets_libraries] ||= {}
      state[:assets_content] ||= []
      state
    end

    # execute translation for value if this value is like: t(admin.my_text) ==> My Text
    def cama_print_i18n_value(value)
      return value unless value.is_a?(String)
      return value unless value.start_with?('t(') && value.end_with?(')')

      # Use an exclusive end index to strip the trailing ')' without nil-coercion.
      key = value[2...-1].strip
      # If the expression uses matching single/double quotes, unwrap the key before translation;
      # the quoted form still only accepts simple i18n key characters: a-z, A-Z, 0-9, _, ., and -.
      quoted_key_match = key.match(/\A(['"])([a-zA-Z0-9_.-]+)\1\z/)
      key = quoted_key_match[2] if quoted_key_match

      # Only translate simple i18n keys so arbitrary Ruby is never evaluated.
      # Allowed chars: a-z, A-Z, 0-9, _, ., and -.
      return value unless key.match?(/\A[a-zA-Z0-9_.-]+\z/)

      I18n.t(key)
    end
  end
end
