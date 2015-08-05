=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class Plugins::Attack::AdminController < Apps::PluginsAdminController
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