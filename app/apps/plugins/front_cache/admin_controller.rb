class Plugins::FrontCache::AdminController < CamaleonCms::Apps::PluginsAdminController
  include Plugins::FrontCache::FrontCacheHelper
  def settings
    @caches = current_site.get_meta("front_cache_elements", {paths: []})
    @caches[:paths] << "" unless @caches[:paths].present?
  end

  def save_settings
    current_site.set_meta("front_cache_elements", {paths: ((params[:cache][:paths] || []).delete_if{|a| !a.present?  } ||[]),
                                                   posts: (params[:cache][:posts]||[]),
                                                   post_types: (params[:cache][:post_type]||[]),
                                                   skip_posts: (params[:cache][:skip_posts]||[]),
                                                   cache_login: params[:cache][:cache_login],
                                                   home: params[:cache][:home]
                                                  })
    flash[:notice] = "#{t('plugin.front_cache.message.settings_saved')}"
    redirect_to action: :settings
  end

  def clean_cache
    flash[:notice] = "#{t('plugin.front_cache.message.cache_destroyed')}"
    front_cache_clean()
    redirect_to :back
  end

end
