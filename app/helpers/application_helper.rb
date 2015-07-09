module ApplicationHelper
  def my_logger
    @@my_logger ||= Logger.new("#{Rails.root}/log/my.log")
  end

  def log(data=nil)
    my_logger.debug data
  end

  def _log(data = nil)
    Rails.logger.debug data
  end

  def _env
    (Rails.env.production?)? 'production' : 'development'
  end

  def _dev
    !Rails.env.production?
  end

  # cross domain cookie
  def _cookie(key, value=nil, perm = false)
    if value.present?
      if perm
        cookies.permanent[key.to_sym] = {:value => value, :domain => :all}
      else
        cookies[key.to_sym] = {:value => value, :domain => :all}
      end
    elsif value == false
      cookies.delete(key.to_sym, :domain => :all)
    else
      cookies[key.to_sym]
    end
  end


  def sendmail(email,subject='Tiene una notificacion',content='',from=nil,attachs=[],current_site=@current_site, template_path='html_mailer',template_name='sender')
    #email = 'cesarion23@gmail.com' if _dev
    from = current_site.get_option('email') if from.nil?
    from = current_site.users.admin_scope.first.email if from.nil?
    HtmlMailer.sender(email, "#{subject} - #{@current_site.the_title}", content, "#{@current_site.the_title}"+"<#{from}>" , attachs, root_url, current_site, template_path,template_name).deliver_now
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

end

