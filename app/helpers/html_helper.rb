=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
#encoding: utf-8
module HtmlHelper
  def html_helpers_init
    @_assets_libraries = {}
    @_assets_content = []
  end

  # enable to load admin libraries (colorpicker, datepicker, form_builder, tinymce, form_ajax, cropper)
  def add_asset_library(*keys)
    keys.each do |key|
      library = assets_libraries[key.to_sym]
      @_assets_libraries[key.to_sym] = library if library.present?
    end
  end

  # add asset libraries (js, css)
  # { library_key2:{ js: [], css: [] }, library_key1:{ js: [], css: [] }, ...}
  def append_asset_libraries(libraries)
    libraries.each do |key, library|
      if @_assets_libraries.include?(key)
        @_assets_libraries[key.to_sym] = @_assets_libraries[key.to_sym].merge(library)
      else
        @_assets_libraries[key.to_sym] = library
      end
    end
  end

  # add asset content into custom assets
  # content may be: <script>alert()</script>
  # content may be: <style>a{color: red;}</style>
  # this will be printed with <%raw draw_custom_assets %>
  def append_asset_content(content)
    @_assets_content << content
  end

  # return all js libraries added [aa.js, bb,js, ..]
  # def get_assets_js
  def draw_custom_assets
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

  def _get_options_html_from_items(terms, level = 0)
    options = []
    terms.all.each do |term|
      options << [("—"*level) + term.name, term.id] unless @term.id == term.id
      children = term.children
      options += _get_options_html_from_items(children, level + 1) if children.size > 0
    end
    options
  end

  def _get_form_element(type, name = '', label = '', value_default = '', extra_class="")
    html = ""
    for_name = name.parameterize
    case type.to_s
      when 'text', 'url', 'email', 'password', 'hidden'
        html = "<div class=\"form-group\">
                  <label for=\"#{for_name}\">#{label}</label>
                  <input type=\"#{type}\" value=\"#{value_default}\" name=\"#{name}\" id=\"#{for_name}\" class=\"form-control #{extra_class}\">
                </div>"
      when 'textarea'
        html = "<div class=\"form-group\">
                  <label for=\"#{for_name}\">#{label}</label>
                  <textarea name=\"#{name}\" id=\"#{for_name}\" class=\"form-control #{extra_class}\">#{value_default}</textarea>
                </div>"

    end
    html
  end

  def html_tooltip(text='Tooltip', location='left')
    "<a href='javascript:;' title='#{text}' data-toggle='tooltip' data-placement='#{location}'><i class='fa fa-info-circle'></i></a>"
  end

  private
  def assets_libraries
    libs = {}
    libs[:colorpicker] = {js: ['admin/bootstrap-colorpicker']}
    libs[:datepicker] = {js: ['admin/bootstrap-datepicker']}
    libs[:datetimepicker] = {js: ['admin/bootstrap-datetimepicker.min']}
    libs[:tinymce] = {js: ['admin/tinymce/tinymce.min', "admin/tinymce/plugins/filemanager/plugin.min"], css: ["admin/tinymce/skins/lightgray/content.min"]}
    libs[:form_builder] = {css:['admin/form-builder/formbuilder'],js: ['admin/form-builder/vendor', 'admin/form-builder/formbuilder' ]}
    libs[:form_ajax] = {js: ['admin/form/jquery.form']}
    libs[:cropper] = {js: ['admin/form/cropper.min'], css: ['admin/cropper/cropper.min']}
    libs[:post] = {js: ["admin/jquery.tagsinput.min", 'admin/post'], css: ["admin/jquery.tagsinput"]}
    libs[:multiselect] = {js: ['admin/bootstrap-select.js']}
    libs[:validate] = {js: ['admin/jquery.validate']}
    libs[:custom_field] = {js: ['admin/custom_fields']}
    libs[:nav_menu] = {css: ['admin/nestable/jquery.nestable', "admin/nav-menu"], js: ["admin/jquery.nestable", 'admin/nav-menu']}
    libs[:elfinder_front] = {js: ['elfinder_front.js']}
    libs
  end
end
