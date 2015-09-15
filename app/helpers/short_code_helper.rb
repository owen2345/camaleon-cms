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
    @_shortcodes = ["widget"]
    @_shortcodes_template = {}
    @_shortcodes_descr = {}
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
    content.scan(/(\[(#{@_shortcodes.join("|")})\s?(.*?)\])/) do |item|
      shortcode, code, attrs = item
      content = content.sub(shortcode, _eval_shortcode(code, attrs, args))
    end
    content
  end

  # render direct a shortcode
  # text: text that contain the shortcode
  # key: shortcode key
  # template: template to render, if nil this will render default render file
    # Also can be a function to execute that instead a render, sample: lambda{|attrs, args| return "my custom content"; }
  # render_shortcode("asda dasdasdas[owen a='1'] [bbb] sdasdas dasd as das[owen a=213]", "owen", lambda{|attrs, args| puts attrs; return "my test"; })
  def render_shortcode(text, key, template = nil)
    text.scan(/(\[(#{key})\s?(.*?)\])/).each do |item|
      shortcode, code, attrs = item
      text = text.sub(shortcode, _eval_shortcode(code, attrs, {}, template))
    end
    text
  end

  private

  # determine the content to replace instead the shortcode
  # return string
  def _eval_shortcode(code, attrs, args={}, template = nil)
    template ||= (@_shortcodes_template[code].present? ? @_shortcodes_template[code] : "shortcode_templates/#{code}")
    if @_shortcodes_template[code].class.name == "Proc"
      res = @_shortcodes_template[code].call(attributes: _shortcode_parse_attr(attrs), args: args)
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
