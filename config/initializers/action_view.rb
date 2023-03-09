# this is a customization to support multiple prefix to render partials
module ActionView
  class LookupContext # :nodoc:
    attr_accessor :use_camaleon_partial_prefixes

    module ViewPaths
      # fix to add camaleon prefix to search partials and layouts
      def find(name, prefixes = [], partial = false, keys = [], options = {})
        if use_camaleon_partial_prefixes.present?
          if !partial && !prefixes.present? && File.exist?(name) # fix for windows ==> render file: '....'
            # puts "rendering specific file (render file: '....')"
          else
            prefixes = [''] unless prefixes.present?
            prefixes = (self.prefixes + prefixes).uniq if prefixes.is_a?(Array)
          end
        end
        @view_paths.find(*cama_args_for_lookup(name, prefixes, partial, keys, options))
      end
      alias find_template find

      # fix to add camaleon prefixes on verify template exist
      def exists?(name, prefixes = [], partial = false, keys = [], **options)
        if use_camaleon_partial_prefixes.present?
          prefixes = [''] unless prefixes.present?
          prefixes = (prefixes + self.prefixes).uniq if prefixes.is_a?(Array)
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
    end
  end
end
