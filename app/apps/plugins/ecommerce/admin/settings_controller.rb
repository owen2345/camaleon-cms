=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class Plugins::Ecommerce::Admin::SettingsController < Plugins::Ecommerce::AdminController
  def index
    @setting = current_site.meta[:_setting_ecommerce] || {}
  end


  def saved
    current_site.set_meta('_setting_ecommerce', params[:setting])
    flash[:notice] = t('admin.post_type.message.updated')
    redirect_to action: :index
  end

  #  http://finance.yahoo.com/d/quotes.csv?e=.csv&f=c4l1&s=EURUSD=X
end
