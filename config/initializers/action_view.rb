# frozen_string_literal: true

# this is a customization to support multiple prefix to render partials
module ActionView
  class LookupContext # :nodoc:
    attr_accessor :use_camaleon_partial_prefixes

    module ViewPaths
      # fix to add camaleon prefix to search partials and layouts
      def find(name, prefixes = [], partial = false, keys = [], options = {})
        if use_camaleon_partial_prefixes.present?
          scoped_prefixes = cama_theme_scoped_prefixes(prefixes)
          theme_scoped = scoped_prefixes.present?
          prefixes = scoped_prefixes if theme_scoped
          if !partial && prefixes.blank? && File.exist?(name) # fix for windows ==> render file: '....'
            # puts "rendering specific file (render file: '....')"
          else
            prefixes = [''] if prefixes.blank?
            prefixes = (self.prefixes + prefixes).uniq if prefixes.is_a?(Array) && !theme_scoped
          end
        end
        @view_paths.find(*cama_args_for_lookup(name, prefixes, partial, keys, options))
      end
      alias find_template find

      # fix to add camaleon prefixes on verify template exist
      def exists?(name, prefixes = [], partial = false, keys = [], **options)
        if use_camaleon_partial_prefixes.present?
          scoped_prefixes = cama_theme_scoped_prefixes(prefixes)
          theme_scoped = scoped_prefixes.present?
          prefixes = scoped_prefixes if theme_scoped
          prefixes = [''] if prefixes.blank?
          prefixes = (prefixes + self.prefixes).uniq if prefixes.is_a?(Array) && !theme_scoped
        end
        @view_paths.exists?(*cama_args_for_lookup(name, prefixes, partial, keys, options))
      end
      alias template_exists? exists?

      private

      # Rails 7 removed a private API method used by Camaleon. This method
      # re-implements it or delegates to it, depending on Rails version.
      def cama_args_for_lookup(name, prefixes, partial, keys, details_options)
        if Rails.version.to_i < 7
          args_for_lookup(name, prefixes, partial, keys, details_options)
        else
          # Re-implement the :args_for_lookup method from Rails < 7
          name, prefixes = normalize_name(name, prefixes)
          prefixes = prefixes.map { |prefix| prefix.start_with?('/') ? prefix[1..] : prefix }
          details, details_key = detail_args_for(details_options)
          [name, prefixes, partial || false, details, details_key, keys]
        end
      end

      # Detects a lookup whose explicit prefixes are *entirely* scoped to the
      # current (frontend) theme -- i.e. its `themes/<slug>/views...` prefixes
      # and/or the gem `camaleon_cms/default_theme` fallback, and nothing else
      # (e.g. a partial rendered from within a theme, or a theme preview). In
      # that case the lookup is restricted to that theme and the global
      # `self.prefixes` are NOT merged, so a different theme / per-site override
      # does not leak in.
      #
      # When the explicit prefixes also include non-theme prefixes (e.g. a
      # plugin front controller rendering its own `plugins/<name>/...`
      # templates), it returns a blank list, signalling the caller to merge
      # `self.prefixes` as before -- this keeps the plugin's own
      # `plugins/<name>/views/...` lookup prefix reachable.
      def cama_theme_scoped_prefixes(prefixes)
        theme = CurrentRequest.frontend_current_theme
        slug = theme&.slug
        return if slug.blank? || prefixes.blank? || !prefixes.is_a?(Array)

        selected = prefixes.select do |prefix|
          prefix.include?("themes/#{slug}/views") || prefix == 'camaleon_cms/default_theme'
        end
        selected if selected.length == prefixes.length
      end
    end
  end
end
