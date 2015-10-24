=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
#encoding: utf-8
module CamaleonCms::HtmlHelper
  def cama_html_helpers_init
    @_assets_libraries = {}
    @_assets_content = []
  end

  # enable to load admin or registered libraries (colorpicker, datepicker, form_builder, tinymce, form_ajax, cropper)
  # sample: add_asset_library("datepicker", "colorpicker")
  def cama_load_libraries(*keys)
    keys.each do |key|
      library = cama_assets_libraries[key.to_sym]
      @_assets_libraries[key.to_sym] = library if library.present?
    end
  end
  alias_method :add_asset_library, :cama_load_libraries

  # add custom asset libraries (js, css or both) for the current request, also you can add extra css or js files for existent libraries
  # sample: (add new library)
  #   append_asset_libraries({"my_library_key"=> { js: [plugin_asset("js/my_js"), "plugins/myplugin/assets/js/my_js2"], css: [plugin_asset("css/my_css"), "plugins/myplugin/assets/css/my_css2"] }})
  # sample: (update existent library)
  #   append_asset_libraries({"colorpicker"=>{js: [[plugin_asset("js/my_custom_js")] } })
  # return nil
  def cama_load_custom_assets(libraries)
    libraries.each do |key, library|
      if @_assets_libraries.include?(key)
        @_assets_libraries[key.to_sym] = @_assets_libraries[key.to_sym].merge(library)
      else
        @_assets_libraries[key.to_sym] = library
      end
    end
  end
  alias_method :append_asset_libraries, :cama_load_custom_assets

  # add asset content into custom assets
  # content may be: <script>alert()</script>
  # content may be: <style>a{color: red;}</style>
  # this will be printed with <%raw cama_draw_custom_assets %>
  def append_asset_content(content)
    @_assets_content << content
  end

  # return all js libraries added [aa.js, bb,js, ..]
  # def get_assets_js
  def cama_draw_custom_assets
    cama_html_helpers_init unless @_assets_libraries.present?
    libs = []
    @_assets_libraries.each do |key, assets|
      libs += assets[:css] if assets[:css].present?
    end
    css = stylesheet_link_tag *libs.uniq, media: "all"

    libs = []
    @_assets_libraries.each do |key, assets|
      libs += assets[:js] if assets[:js].present?
    end
    js = javascript_include_tag *libs.uniq
    css + "\n" + js + "\n" + @_assets_content.join("").html_safe
  end

  # return category tree for category dropdown
  # each level is prefixed with -
  # level: internal recursive control
  def cama_get_options_html_from_items(terms, level = 0)
    options = []
    terms.all.each do |term|
      options << [("—"*level) + term.name, term.id] unless @term.id == term.id
      children = term.children
      options += cama_get_options_html_from_items(children, level + 1) if children.size > 0
    end
    options
  end

  # create a html tooltip to include anywhere
  # text: text of the tooltip
  # location: location of the tooltip (left | right | top |bottom)
  def cama_html_tooltip(text='Tooltip', location='left')
    "<a href='javascript:;' title='#{text}' data-toggle='tooltip' data-placement='#{location}'><i class='fa fa-info-circle'></i></a>"
  end

  private
  def cama_assets_libraries
    libs = {}
    libs[:colorpicker] = {js: ['camaleon_cms/admin/bootstrap-colorpicker'], css: ["camaleon_cms/admin/colorpicker.css"]}
    libs[:datepicker] = {js: ['camaleon_cms/admin/bootstrap-datepicker']}
    libs[:datetimepicker] = {js: ['camaleon_cms/admin/bootstrap-datetimepicker.min']}
    libs[:tinymce] = {js: ['camaleon_cms/admin/tinymce/tinymce.min', "camaleon_cms/admin/tinymce/plugins/filemanager/plugin.min"], css: ["camaleon_cms/admin/tinymce/skins/lightgray/content.min"]}
    libs[:form_builder] = {css:['camaleon_cms/admin/form-builder/formbuilder'],js: ['camaleon_cms/admin/form-builder/vendor', 'camaleon_cms/admin/form-builder/formbuilder' ]}
    libs[:form_ajax] = {js: ['camaleon_cms/admin/form/jquery.form']}
    libs[:cropper] = {js: ['camaleon_cms/admin/form/cropper.min'], css: ['camaleon_cms/admin/cropper/cropper.min']}
    libs[:post] = {js: ["camaleon_cms/admin/jquery.tagsinput.min", 'camaleon_cms/admin/post'], css: ["camaleon_cms/admin/jquery.tagsinput"]}
    libs[:multiselect] = {js: ['camaleon_cms/admin/bootstrap-select.js']}
    libs[:validate] = {js: ['camaleon_cms/admin/jquery.validate']}
    libs[:nav_menu] = {css: ['camaleon_cms/admin/nestable/jquery.nestable', "camaleon_cms/admin/nav-menu"], js: ["camaleon_cms/admin/jquery.nestable", 'camaleon_cms/admin/nav-menu']}
    libs[:elfinder_front] = {js: ['camaleon_cms/elfinder_front.js']}
    libs[:admin_intro] = {js: ['camaleon_cms/admin/introjs/intro.min'], css: ["camaleon_cms/admin/introjs/introjs.min"]}
    libs
  end
end
