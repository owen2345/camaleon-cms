module Plugins::FrontCache::FrontCacheHelper

  # save as cache all pages configured on settings of this plugin for public users
  def front_cache_front_before_load
    if current_site.get_option("refresh_cache") # clear cache every restart server
      front_cache_clean
      current_site.set_option("refresh_cache", false)
    end

    return if signin? || Rails.env == "development" || Rails.env == "test" || !request.get? # avoid cache if current visitor is logged in or development environment

    cache_key = request.fullpath.parameterize
    if !flash.keys.present? && front_cache_exist?(cache_key) # recover cache file
      Rails.logger.info "Camaleon CMS - readed cache: #{front_cache_plugin_get_path(cache_key)}"
      response.headers['PLUGIN_FRONT_CACHE'] = 'TRUE'
      args = {data: front_cache_get(cache_key).gsub("{{form_authenticity_token}}", form_authenticity_token)}; hooks_run('front_cache_reading_cache', args)
      render text: args[:data]
      return
    end

    @caches = current_site.get_meta("front_cache_elements")
    @_plugin_do_cache = false
    if @caches[:paths].include?(request.original_url) || @caches[:paths].include?(request.path_info) || front_cache_plugin_match_path_patterns?(request.original_url, request.path_info) || (params[:action] == 'index' && params[:controller] == 'camaleon_cms/frontend' && @caches[:home].present?) # cache paths and home page
      @_plugin_do_cache = true
    elsif params[:action] == "post" && params[:controller] == 'camaleon_cms/frontend' && !params[:draft_id].present?
      begin
        post = current_site.the_posts.find_by_slug(params[:slug]).decorate
        if post.can_visit? && post.visibility != "private"
          post = post
          if (@caches[:skip_posts] || []).include?(post.id.to_s)
            @_plugin_do_cache = false
          else
            @_plugin_do_cache = true  if (@caches[:post_types] || []).include?(post.post_type_id.to_s) || (@caches[:posts] || []).include?(post.id.to_s)
          end
        end
      rescue # skip post not found
      end
    end
    response.headers['PLUGIN_FRONT_CACHE'] = 'TRUE' if @_plugin_do_cache
  end


  def front_cache_front_after_load
    cache_key = request.fullpath.parameterize
    if @_plugin_do_cache && !flash.keys.present?
      args = {data: response.body
                        .gsub(/csrf-token" content="(.*?)"/, 'csrf-token" content="{{form_authenticity_token}}"')
                        .gsub(/name="authenticity_token" value="(.*?)"/, 'name="authenticity_token" value="{{form_authenticity_token}}"')}
      hooks_run('front_cache_writing_cache', args)
      front_cache_plugin_cache_create(cache_key, args[:data])
      Rails.logger.info "Camaleon CMS - cache saved as: #{front_cache_plugin_get_path(cache_key)}"
    end
  end

  # on install plugin
  def front_cache_on_active(plugin)
    current_site.set_meta("front_cache_elements", {paths: [],
        posts: [],
        post_types: [current_site.post_types.where(slug: "page").first.id],
        skip_posts: [],
        home: true,
        cache_login: true}) unless current_site.get_meta("front_cache_elements", nil).present?
  end

  # on uninstall plugin
  def front_cache_on_inactive(plugin)
    # current_site.delete_meta("front_cache_elements")
  end

  # cache actions (for logged users)
  def front_cache_on_render(args)
  end

  # expire cache for a page after comment registered or updated
  def front_cache_before_load
  end

  def front_cache_plugin_options(arg)
    arg[:links] << link_to(t('plugin.front_cache.settings'), admin_plugins_front_cache_settings_path)
    arg[:links] << link_to(t('plugin.front_cache.clean_cache'), admin_plugins_front_cache_clean_path)
  end

  # save as cache all post requests
  def front_cache_post_requests
    if (request.post? || request.patch?)
      front_cache_clean()
    end
  end

  # clear all frontend cache files
  def front_cache_clean
    FileUtils.rm_rf(front_cache_plugin_get_path) # clear site pages cache
  end

  private

  def front_cache_exist?(key)
    File.exist?(front_cache_plugin_get_path(key))
  end

  def front_cache_get(key)
    File.read(front_cache_plugin_get_path(key))
  end

  def front_cache_destroy(key)
    FileUtils.rm_f(front_cache_plugin_get_path(key)) # clear site pages cache
  end

  def front_cache_plugin_cache_create(key, content)
    FileUtils.mkdir_p(front_cache_plugin_get_path) unless Dir.exist?(front_cache_plugin_get_path)
    File.open(front_cache_plugin_get_path(key), 'wb'){ |fo| fo.write(content) }
    content
  end

  # return the physical path of cache directory
  # key: (string, optional) the key of the cached page
  def front_cache_plugin_get_path(key = nil)
    unless key.nil?
      Rails.root.join("tmp", "cache", "pages", current_site.id.to_s, "#{key}.html").to_s
    else
      Rails.root.join("tmp", "cache", "pages", current_site.id.to_s).to_s
    end

  end

  def front_cache_plugin_match_path_patterns?(key, key2)
    @caches[:paths].any?{|path_pattern| key =~ Regexp.new(path_pattern) || key2 =~ Regexp.new(path_pattern) }
  end
end