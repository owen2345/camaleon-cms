module Plugins::Attack::AttackHelper

  # here all actions on plugin destroying
  # plugin: plugin model
  def attack_on_destroy(plugin)
    current_site.attack.destroy_all
  end

  # here all actions on going to active
  # you can run sql commands like this:
  # results = ActiveRecord::Base.connection.execute(query);
  # plugin: plugin model
  def attack_on_active(plugin)
    current_site.set_meta("attack_config", {get: {sec: 20, max: 10},
                                            post: {sec: 20, max: 5},
                                            msg: "#{t('plugin.attack.form.request_limit_exceeded')}",
                                            ban: 5,
                                            cleared: Time.now
                                          })

    unless ActiveRecord::Base.connection.table_exists? 'plugins_attacks'
      ActiveRecord::Base.connection.create_table :plugins_attacks do |t|
        t.string :path, index: true
        t.string :browser_key, index: true
        t.belongs_to :site, index: true
        t.datetime "created_at"
      end
    end
    CamaleonCms::Site.class_eval do
      has_many :attack, class_name: "Plugins::Attack::Models::Attack"
    end
  end

  # here all actions on going to inactive
  # plugin: plugin model
  def attack_on_inactive(plugin)
    current_site.attack.destroy_all
  end

  def attack_app_before_load()
    cache_ban = Rails.cache.read(cama_get_session_id)
    if cache_ban.present? # render banned message if it was banned
      render text: cache_ban, layout: false
      return
    end

    # save cache requests
    attack_check_request
  end

  private
  def attack_check_request
    config = current_site.get_meta("attack_config")
    q = current_site.attack.where(browser_key: cama_get_session_id, path: attack_request_key)
    return unless config.present?

    # clear past requests
    if (Time.parse(config[:cleared]) rescue 2.hours.ago) < 1.hour.ago
      current_site.attack.where("plugins_attacks.created_at < ?", 1.hour.ago).delete_all
      config[:cleared] = Time.now.to_s
      current_site.set_meta("attack_config", config)
    end

    # post request
    if (request.post? || request.patch?)
      r = q.where(created_at: config[:post][:sec].to_i.seconds.ago..Time.now)
      if r.count > config[:post][:max].to_i
        Rails.cache.write(cama_get_session_id, config[:msg], expires_in: config[:ban].to_i.minutes)
        # send an email to administrator with request info (ip, browser, if logged then send user info
        render text: config[:msg]
        return
      end

    # get request
    else
      r = q.where(created_at: config[:get][:sec].to_i.seconds.ago..Time.now)
      if r.count > config[:get][:max].to_i
        Rails.cache.write(cama_get_session_id, config[:msg], expires_in: config[:ban].to_i.minutes)
        render text: config[:msg]
        return
      end
    end
    q.create()
  end

  def attack_request_key(method = nil)
    "#{method.present? ? method : ((request.post? || request.patch?)?"post":"get")}_#{request.path_info.split("?").first}"
  end

  def attack_plugin_options(arg)
    arg[:links] << link_to(t('plugin.attack.settings'), admin_plugins_attack_settings_path)
  end
end
