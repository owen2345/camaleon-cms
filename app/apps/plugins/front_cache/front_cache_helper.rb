module Plugins
  module FrontCache
    module FrontCacheHelper
      # save as cache all pages configured on settings of this plugin for public users
      def front_cache_front_before_load
        if current_site.get_option('refresh_cache') # clear cache every restart server unless option checked in settings
          front_cache_clean unless current_site.get_meta('front_cache_elements')[:preserve_cache_on_restart]
          current_site.set_option('refresh_cache', false)
        end

        # avoid cache if current visitor is logged in or development
        return if signin? || Rails.env.development? || Rails.env.test? || !request.get?

        cache_key = front_cache_plugin_cache_key
        @caches = current_site.get_meta('front_cache_elements')
        if !flash.keys.present? && front_cache_exist?(cache_key) # recover cache item
          Rails.logger.info "Camaleon CMS - readed cache: #{front_cache_plugin_get_path(cache_key)}"
          response.headers['PLUGIN_FRONT_CACHE'] = 'TRUE'
          args = { data: front_cache_get(cache_key).gsub('{{form_authenticity_token}}', form_authenticity_token) }
          hooks_run('front_cache_reading_cache', args)
          render html: args[:data].html_safe
          return
        end

        @_plugin_do_cache = false
        if @caches[:paths].include?(request.original_url) || @caches[:paths].include?(request.path_info) || front_cache_plugin_match_path_patterns?(request.original_url, request.path_info) || (params[:action] == 'index' && params[:controller] == 'camaleon_cms/frontend' && @caches[:home].present?) # cache paths and home page
          @_plugin_do_cache = true
        elsif params[:action] == 'post' && params[:controller] == 'camaleon_cms/frontend' && !params[:draft_id].present?
          begin
            post = current_site.the_posts.find_by_slug(params[:slug]).decorate
            if post.can_visit? && post.visibility != 'private'
              if (@caches[:skip_posts] || []).include?(post.id.to_s)
                @_plugin_do_cache = false
              elsif (@caches[:post_types] || []).include?(post.post_type_id.to_s) || (@caches[:posts] || []).include?(post.id.to_s)
                @_plugin_do_cache = true
              end
            end
          rescue StandardError # skip post not found
          end
        end
        response.headers['PLUGIN_FRONT_CACHE'] = 'TRUE' if @_plugin_do_cache
      end

      def front_cache_front_after_load
        cache_key = front_cache_plugin_cache_key
        return unless @_plugin_do_cache && !flash.keys.present?

        args = { data: response.body
                               .gsub(/csrf-token" content="(.*?)"/, 'csrf-token" content="{{form_authenticity_token}}"')
                               .gsub(/name="authenticity_token" value="(.*?)"/, 'name="authenticity_token" value="{{form_authenticity_token}}"') }
        hooks_run('front_cache_writing_cache', args)
        front_cache_plugin_cache_create(cache_key, args[:data])
        Rails.logger.info "Camaleon CMS - cache saved as: #{front_cache_plugin_get_path(cache_key)}"
      end

      # on install plugin
      def front_cache_on_active(_plugin)
        return if current_site.get_meta('front_cache_elements', nil).present?

        current_site.set_meta('front_cache_elements', { paths: [],
                                                        posts: [],
                                                        post_types: [current_site.post_types.where(slug: 'page').first.id],
                                                        skip_posts: [],
                                                        home: true,
                                                        cache_login: true,
                                                        cache_counter: 0 })
      end

      # on uninstall plugin
      def front_cache_on_inactive(plugin)
        # current_site.delete_meta("front_cache_elements")
      end

      # cache actions (for logged users)
      def front_cache_on_render(args); end

      # expire cache for a page after comment registered or updated
      def front_cache_before_load; end

      def front_cache_plugin_options(arg)
        arg[:links] << link_to(t('plugin.front_cache.settings'), admin_plugins_front_cache_settings_path)
        arg[:links] << link_to(t('plugin.front_cache.clean_cache'), admin_plugins_front_cache_clean_path)
      end

      # save as cache all post requests
      def front_cache_post_requests
        return unless request.post? || request.patch?

        front_cache_clean
      end

      # clear all frontend cache items
      def front_cache_clean
        @caches = current_site.get_meta('front_cache_elements')
        if @caches[:invalidate_only]
          @caches[:cache_counter] += 1
        else
          Rails.cache.clear
          @caches[:cache_counter] = 0
        end
        current_site.set_meta('front_cache_elements', @caches)
      end

      private

      def front_cache_exist?(key)
        !Rails.cache.read(front_cache_plugin_get_path(key)).nil?
      end

      def front_cache_get(key)
        Rails.cache.read(front_cache_plugin_get_path(key))
      end

      def front_cache_plugin_cache_create(key, content)
        Rails.cache.write(front_cache_plugin_get_path(key), content)
      end

      # return the physical path of cache directory
      # key: (string, optional) the key of the cached page
      def front_cache_plugin_get_path(key = nil)
        if key.nil?
          "pages/#{@caches[:cache_counter]}/#{current_site.id}"
        else
          "pages/#{@caches[:cache_counter]}/#{current_site.id}/#{key}"
        end
      end

      def front_cache_plugin_match_path_patterns?(key, key2)
        @caches[:paths].any? { |path_pattern| key =~ Regexp.new(path_pattern) || key2 =~ Regexp.new(path_pattern) }
      end

      def front_cache_plugin_cache_key
        uri = [request.protocol + request.host_with_port, request.fullpath].join('/')
        uri.parameterize
      end
    end
  end
end
