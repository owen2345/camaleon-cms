=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
module ShortCodeHelper
  # Internal method
  def shortcodes_init
    @_shortcodes = []
    @_shortcodes_template = {}
    @_shortcodes_descr = {}

    # shortcode_add("load_libraries", nil, "Renderize the widget content in this place. Sample: [widget widget_key]")

    shortcode_add("load_libraries",
                  lambda{|attrs, args| add_asset_library(*attrs["data"].to_s.split(",")); return ""; },
                  "Permit to load libraries on demand, sample: [load_libraries data='datepicker,tinymce']")

    shortcode_add("asset",
                  lambda{|attrs, args|
                    url = attrs["as_path"].present? ? ActionController::Base.helpers.asset_url(attrs["file"]) : ActionController::Base.helpers.asset_url(attrs["file"])
                    if attrs["image"].present?
                      ActionController::Base.helpers.image_tag(attrs["file"], class: attrs["class"], style: attrs["style"])
                    else
                      url
                    end
                  },
                  "Permit to generate an asset url (
                    add file='' asset file path,
                    add as_path='true' to generate only the path and not the full url,
                    add class='my_class' to setup image class,
                    add style='height: 100px; width: 200px;...' to setup image style,
                    add image='true' to generate the image tag with this url),
                  sample: <img src=\"[asset as_path='true' file='themes/my_theme/assets/img/signature.png']\" /> or [asset image='true' file='themes/my_theme/assets/img/signature.png' style='height: 50px;']")

    shortcode_add("post_url",
                  lambda{|attrs, args|
                    post = current_site.the_post(attrs["id"].to_i) if attrs["id"].present?
                    post = current_site.the_post(attrs["key"].to_s) if attrs["key"].present?
                    if post.present?
                      if attrs["link"].present?
                        return ActionController::Base.helpers.link_to(attrs["title"].present? ? attrs["title"].html_safe : post.the_title, post.the_url, target: attrs["target"])
                      else
                        return post.the_url
                      end
                    end
                    return ""
                  },
                  "Permit to generate the url of a post (add path='' to generate the path and not the full url,
                    add id='123' to use the POST ID,
                    add key='my_slug' to use the POST SLUG,
                    add link='true' to generate the full link,
                    add title='my title' text of the link (default post title),
                    add target='_blank' to open the link in a new window this is valid only if link is present),
                  sample: [post_url id='122' link=true target='_blank']")
  end

  # add shortcode
  # key: shortcode key
  # template: template to render, if nil will render "shortcode_templates/<key>"
  # Also can be a function to execute that instead a render, sample: lambda{|attrs, args| return "my custom content"; }
  # descr: description for shortcode
  def shortcode_add(key, template = nil, descr = '')
    @_shortcodes << key
    @_shortcodes_template = @_shortcodes_template.merge({"#{key}"=> template}) if template.present?
    @_shortcodes_descr[key] = descr if descr.present?
  end

  # add or update shortcode template
  # key: chortcode key to add or update
  # template: template to render, if nil will render "shortcode_templates/<key>"
  def shortcode_change_template(key, template = nil)
    @_shortcodes_template[key] = template
  end

  # delete shortcode
  # key: chortcode key to delete
  def shortcode_delete(key)
    @_shortcodes.delete(key)
  end

  # run all shortcodes in the content
  # content: (string) text to find a short codes
  # args: custom arguments to pass for short codes render, sample: {owner: my_model, a: true}
  # if args != Hash, this will re send as args = {owner: args}
  def do_shortcode(content, args = {})
    args = {owner: args} unless args.is_a?(Hash)
    content.scan(/#{cama_reg_shortcode}/) do |item|
    # content.scan(/(\[(#{@_shortcodes.join("|")})\s?(.*?)\])/) do |item|
      shortcode, code, space, attrs = item
      content = content.sub(shortcode, _eval_shortcode(code, attrs, args))
    end
    content
  end

  # remove all shortcodes from text
  # Arguments
  #   text: String that contains shortcodes
  # return String
  def cama_strip_shortcodes(text)
    text.gsub(/#{cama_reg_shortcode}/, "")
  end

  # render direct a shortcode
  # text: text that contain the shortcode
  # key: shortcode key
  # template: template to render, if nil this will render default render file
  # Also can be a function to execute that instead a render, sample: lambda{|attrs, args| return "my custom content"; }
  # render_shortcode("asda dasdasdas[owen a='1'] [bbb] sdasdas dasd as das[owen a=213]", "owen", lambda{|attrs, args| puts attrs; return "my test"; })
  def render_shortcode(text, key, template = nil)
    text.scan(/#{cama_reg_shortcode(key)}/).each do |item|
      shortcode, code, space, attrs = item
      text = text.sub(shortcode, _eval_shortcode(code, attrs, {}, template))
    end
    text
  end

  private
  # create the regexpression for shortcodes
  # codes: (String) shortcode keys separated by |
  # sample: load_libraries|asset
  # if empty, codes will be replaced with all registered shortcodes
  # Return: (String) reg expression string
  def cama_reg_shortcode(codes = nil)
    "(\\[(#{codes || @_shortcodes.join("|")})(\s|\\]){1}(.*?)\\])"
  end

  # determine the content to replace instead the shortcode
  # return string
  def _eval_shortcode(code, attrs, args={}, template = nil)
    template ||= (@_shortcodes_template[code].present? ? @_shortcodes_template[code] : "shortcode_templates/#{code}")
    if @_shortcodes_template[code].class.name == "Proc"
      res = @_shortcodes_template[code].call(_shortcode_parse_attr(attrs), args)
    else
      res = render :file => template, :locals => {attributes: _shortcode_parse_attr(attrs), args: args}
    end
    res
  end

  # parse the attributes of a shortcode
  def _shortcode_parse_attr(text)
    res = {}
    return res unless text.present?
    text.scan(/(\w+)\s*=\s*"([^"]*)"(?:\s|$)|(\w+)\s*=\s*\'([^\']*)\'(?:\s|$)|(\w+)\s*=\s*([^\s\'"]+)(?:\s|$)|"([^"]*)"(?:\s|$)|(\S+)(?:\s|$)/).each do |item|
      item.each_with_index do |c, index|
        if c.present?
          res[c] = item[index+1]
          break
        end
      end
    end
    res
  end
end
