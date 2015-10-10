=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
module CamaleonHelper
  # send and email
  # email: email to
  # subject: Subject of the email
  # content: content of the email
  # from: email figured as from
  # attachs: array of files to be attached to the email
  # layout_name: path of the template to render
  # template_name: template name to render in template_path
  def sendmail(email,subject='Tiene una notificacion',content='',from=nil,attachs=[],template_name = 'mailer', layout_name = 'mailer')
    Thread.abort_on_exception=true
    Thread.new do
      HtmlMailer.sender(email, subject, content, from, attachs, root_url, current_site, template_name, layout_name).deliver_now
      ActiveRecord::Base.connection.close
    end
  end

  # create the html link with the url passed
  # verify if current user is logged in, if not, then return nil
  # return html link
  def cama_edit_link(url, title = nil, attrs = { })
    return '' unless current_user.present?
    attrs = {target: "_blank", style: "font-size:11px !important;cursor:pointer;"}.merge(attrs)
    ActionController::Base.helpers.link_to("&rarr; #{title || ct("edit")}".html_safe, url, attrs)
  end

  # execute controller action and return response
  def requestAction(controller,action,params={})
    controller.class_eval{
      def params=(params); @params = params end
      def params; @params end
    }
    c = controller.new
    c.request = @_request
    c.response = @_response
    c.params = params
    c.send(action)
    c.response.body
  end

  # deprecated helper
  def array_change_key_case(hash)
    result = hash.inject({}) do |hash, keys|
      hash[raw(keys[1])] = keys[0]
      hash
    end
  end

  # theme common translation text
  # key: key for translation
  # language: language for the translation, if it is nil, then will use current site language
  # valid only for common translations, If you can to use other translations for themes or plugins,
  # you can use the default of rails (I18n.t)
  def ct(key, language = nil)
    language = language || I18n.locale
    r = {flag: false, key: key, translation: "", locale: language.to_sym}
    hooks_run("on_translation", r)
    return r[:translation] if r[:flag]
    translate("common.#{key}", locale: language)
  end

  # check if current request was for admin panel
  def is_admin_request?
    !(@_admin_menus.nil?)
  end

  # generate loop categories html sitemap links
  # this is a helper for sitemap generator to print categories, sub categories and post contents in html list format
  def cama_sitemap_cats_generator(cats)
    res = []
    cats.decorate.each do |cat|
      next if @r[:skip_cat_ids].include?(cat.id)
      res_posts = []
      cat.the_posts.decorate.each do |post|
        next if @r[:skip_post_ids].include?(post.id)
        res_posts << "<li><a href='#{post.the_url}'>#{post.the_title}</a></li>"
      end
      res << "<li><h4><a href='#{cat.the_url}'>#{cat.the_title}</a></h4><ul>#{res_posts.join("")}</ul></li>"
      res << cama_sitemap_cats_generator(cat.the_categories)
    end
    res.join("")
  end
end
