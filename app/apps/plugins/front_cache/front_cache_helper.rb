module Plugins
  module FrontCache
    module FrontCacheHelper
      # Upper bound on any stored page's life. Stores whose purge is rescued away (RedisCacheStore
      # and MemCacheStore reject the matcher) would otherwise keep retired or never-revisited
      # entries forever — and Redis's default maxmemory-policy is noeviction, so TTL-less bodies
      # would grow until the shared store refuses writes. An expired entry is an ordinary miss: the
      # page is re-rendered and re-cached.
      FRONT_CACHE_EXPIRATION = 1.week
      # cache all pages configured in this plugin's settings for public users
      def front_cache_front_before_load
        if current_site.get_option('refresh_cache') # clear cache every restart server unless option checked in settings
          front_cache_clean unless current_site.get_meta('front_cache_elements')[:preserve_cache_on_restart]
          current_site.set_option('refresh_cache', false)
        end

        # avoid cache if the current visitor is logged in, or we're in the development or test environment
        return if signin? || Rails.env.development? || Rails.env.test? || !request.get?

        cache_key = front_cache_plugin_cache_key
        @caches = current_site.get_meta('front_cache_elements')
        # Single read: the old exist?-then-get pair issued two store reads, and an entry vanishing
        # between them (a concurrent admin purge, TTL expiry) left .gsub running on nil — a
        # visitor-facing 500.
        cached_body = flash.keys.blank? ? front_cache_get(cache_key) : nil
        if cached_body # recover cache item
          Rails.logger.info "Camaleon CMS - readed cache: #{front_cache_plugin_get_path(cache_key)}"
          response.headers['PLUGIN_FRONT_CACHE'] = 'TRUE'
          args = { data: cached_body.gsub('{{form_authenticity_token}}', form_authenticity_token) }
          hooks_run('front_cache_reading_cache', args)
          # rubocop:disable Rails/OutputSafety -- This replays a trusted cached page body that was already rendered by Rails.
          render html: args[:data].html_safe
          # rubocop:enable Rails/OutputSafety
          return
        end

        @_plugin_do_cache = false
        # cache paths and home page
        if @caches[:paths].include?(request.original_url) || @caches[:paths].include?(request.path_info) ||
           front_cache_plugin_match_path_patterns?(request.original_url, request.path_info) ||
           (params[:action] == 'index' && params[:controller] == 'camaleon_cms/frontend' && @caches[:home].present?)
          @_plugin_do_cache = true
        elsif params[:action] == 'post' && params[:controller] == 'camaleon_cms/frontend' && params[:draft_id].blank?
          # the_post is a single-record lookup (eager: false) -- no listing preloads for one post
          # Never cache non-public posts. A password-protected post is unlocked per session (visibility_post
          # audit M2), but the page cache is keyed on the URL alone, so caching an unlocked render would
          # serve the protected body to visitors who never entered the password. Private posts are already
          # excluded; password posts must be too.
          if (post = current_site.the_post(params[:slug])) && post.can_visit? && !%w[private
                                                                                     password].include?(post.visibility)
            if (@caches[:skip_posts] || []).include?(post.id.to_s)
              @_plugin_do_cache = false
            elsif (@caches[:post_types] || []).include?(post.post_type_id.to_s) ||
                  (@caches[:posts] || []).include?(post.id.to_s)
              @_plugin_do_cache = true
            end
          end
        end

        response.headers['PLUGIN_FRONT_CACHE'] = 'TRUE' if @_plugin_do_cache
      end

      def front_cache_front_after_load
        cache_key = front_cache_plugin_cache_key
        return unless @_plugin_do_cache && flash.keys.blank?

        body =
          response
          .body.gsub(/csrf-token" content="(.*?)"/, 'csrf-token" content="{{form_authenticity_token}}"')
          .gsub(
            /name="authenticity_token" value="(.*?)"/, 'name="authenticity_token" value="{{form_authenticity_token}}"'
          )
        args = { data: body }
        hooks_run('front_cache_writing_cache', args)
        front_cache_plugin_cache_create(cache_key, args[:data])
        Rails.logger.info "Camaleon CMS - cache saved as: #{front_cache_plugin_get_path(cache_key)}"
      end

      # on install plugin
      def front_cache_on_active(_plugin)
        return if current_site.get_meta('front_cache_elements', nil).present?

        current_site.set_meta(
          'front_cache_elements',
          {
            paths: [],
            posts: [],
            post_types: [current_site.post_types.where(slug: 'page').first.id],
            skip_posts: [],
            home: true,
            cache_login: true
          }
        )
      end

      # on uninstall plugin
      def front_cache_on_inactive(_plugin)
        # current_site.delete_meta("front_cache_elements")
      end

      # cache actions (for logged users)
      def front_cache_on_render(_args); end

      # expire cache for a page after comment registered or updated
      def front_cache_before_load; end

      def front_cache_plugin_options(arg)
        arg[:links] << link_to(t('plugin.front_cache.settings'), admin_plugins_front_cache_settings_path)
        arg[:links] << link_to(t('plugin.front_cache.clean_cache'), admin_plugins_front_cache_clean_path)
      end

      # invalidate the page cache on any content-changing request. PUT and DELETE count: a permanent
      # post deletion rides DELETE (Rack::MethodOverride makes request.post? false for
      # _method=delete forms), and without a bump the deleted page kept being served from cache.
      def front_cache_post_requests
        return unless request.post? || request.put? || request.patch? || request.delete?

        front_cache_clean
      end

      # invalidate all cached pages of the current site
      def front_cache_clean
        # Security: never Rails.cache.clear — the store is shared, and clearing it on every POST also
        # destroyed unrelated entries such as the per-IP login brute-force counter (CaptchaHelper),
        # silently defeating it. Bumping the version compared on every page-cache read (ActiveSupport
        # `version:`) retires all of this site's pages on any store, with no store enumeration.
        #
        # The version lives in its own meta key, apart from the front_cache_elements settings hash:
        # save_settings rewrites that hash wholesale from an earlier read, so a version stored inside
        # it could be reverted by a settings save racing a concurrent bump — and a reverted version
        # resurrects a retired generation as servable.
        current_site.set_meta('front_cache_counter', front_cache_version + 1)
      end

      private

      # Current page-cache version of the site. `.to_i` covers a site that has never invalidated
      # (missing meta) as version 0 — it must never be nil: an entry written with `version: nil`
      # would match ANY requested version and become immune to invalidation.
      def front_cache_version
        current_site.get_meta('front_cache_counter').to_i
      end

      # Physically remove every stored page entry of the current site. Only the explicit admin
      # "Clean cache" action calls this — per-request invalidation is the version bump alone, so the
      # request path never pays a store walk. The pattern is ^-anchored on purpose: with a store
      # :namespace, ActiveSupport's key_matcher recognizes only a leading ^ (composing /^ns:<rest>/);
      # any other source becomes /^ns:.*<source>/, where \A can never match, silently deleting
      # nothing. Keys are single-line, so ^ cannot over-match. Best-effort: delete_matched is
      # optional store API (MemCacheStore raises NotImplementedError, RedisCacheStore accepts only
      # glob Strings, third-party stores raise their own classes) and the version bump has already
      # retired the pages, so any store error is logged and swallowed.
      def front_cache_purge_stored_pages
        Rails.cache.delete_matched(%r{^cama_front_cache/#{current_site.id}/})
      rescue StandardError, NotImplementedError => e
        Rails.logger.warn "Camaleon CMS - front_cache purge skipped: #{e.class}: #{e.message}"
      end

      def front_cache_exist?(key)
        !front_cache_get(key).nil?
      end

      def front_cache_get(key)
        Rails.cache.read(front_cache_plugin_get_path(key), version: front_cache_version)
      end

      # One entry per URL: the version is stored inside the entry, so re-caching a page after an
      # invalidation overwrites the retired body in place on every store — storage is bounded at one
      # entry per cached URL instead of one per URL per invalidation.
      def front_cache_plugin_cache_create(key, content)
        Rails.cache.write(front_cache_plugin_get_path(key), content,
                          version: front_cache_version, expires_in: FRONT_CACHE_EXPIRATION)
      end

      # return the cache key of a stored page
      # key: (string, optional) the key of the cached page
      def front_cache_plugin_get_path(key = nil)
        if key.nil?
          "cama_front_cache/#{current_site.id}"
        else
          "cama_front_cache/#{current_site.id}/#{key}"
        end
      end

      def front_cache_plugin_match_path_patterns?(key, key2)
        front_cache_compiled_path_patterns.any? { |pattern| key =~ pattern || key2 =~ pattern }
      end

      # Security (audit Low): compile the admin-configured patterns once per request and skip any that
      # are malformed -- Regexp.new was rebuilt on every request and raised (500) on an invalid pattern
      # (RegexpError) or a non-String pattern reachable via crafted settings params (TypeError).
      def front_cache_compiled_path_patterns
        @front_cache_compiled_path_patterns ||= (@caches[:paths] || []).filter_map do |pattern|
          Regexp.new(pattern)
        rescue RegexpError, TypeError
          nil
        end
      end

      def front_cache_plugin_cache_key
        uri = [request.protocol + request.host_with_port, request.fullpath].join('/')
        # Security (audit Low): a lossless key. parameterize lowercased and collapsed every run of
        # non-alphanumerics to '-', so distinct URLs shared one cache entry -- a visitor to one
        # cacheable URL could be served the cached body of another.
        Digest::SHA256.hexdigest(uri)
      end
    end
  end
end
