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
