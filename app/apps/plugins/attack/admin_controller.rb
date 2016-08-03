class Plugins::Attack::AdminController < CamaleonCms::Apps::PluginsAdminController
  def settings
    @attack = current_site.get_meta("attack_config")
  end

  def save_settings
    current_site.set_meta("attack_config", {get: {sec: params[:attack][:get_sec], max: params[:attack][:get_max]},
                                            post: {sec: params[:attack][:post_sec]||20, max: params[:attack][:post_max]},
                                            msg: params[:attack][:msg],
                                            ban: params[:attack][:ban],
                                            cleared: Time.now
                                        })
    flash[:notice] = "#{t('plugin.attack.messages.settings_saved')}"
    redirect_to action: :settings
  end

end
