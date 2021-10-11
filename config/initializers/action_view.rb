# this is a customization to support multiple prefix to render partials
module ActionView
  class LookupContext #:nodoc:
    attr_accessor :use_camaleon_partial_prefixes
    module ViewPaths
      # fix to add camaleon prefix to search partials and layouts
      def find(name, prefixes = [], partial = false, keys = [], options = {})
        if use_camaleon_partial_prefixes.present?
          if !partial && !prefixes.present? && File.exist?(name) # fix for windows ==> render file: '....'
            #puts "rendering specific file (render file: '....')"
          else
            prefixes = [""] unless prefixes.present?
            prefixes = (self.prefixes + prefixes).uniq if prefixes.is_a?(Array)
          end
        end
        @view_paths.find(*args_for_lookup(name, prefixes, partial, keys, options))
      end
      alias :find_template :find
    end
  end
end


if Rails.version.to_s[0].to_i == 4
  module ActionView
    class LookupContext #:nodoc:
      module ViewPaths
        # fix to add camaleon prefixes on verify template exist
        def exists?(name, prefixes = [], partial = false, keys = [], options = {})
          if use_camaleon_partial_prefixes.present?
            prefixes = [""] unless prefixes.present?
            prefixes = (prefixes+self.prefixes).uniq if prefixes.is_a?(Array)
          end
          @view_paths.exists?(*args_for_lookup(name, prefixes, partial, keys, options))
        end
        alias :template_exists? :exists?
      end
    end
  end
else
  module ActionView
    class LookupContext #:nodoc:
      module ViewPaths
        # fix to add camaleon prefixes on verify template exist
        def exists?(name, prefixes = [], partial = false, keys = [], **options)
          if use_camaleon_partial_prefixes.present?
            prefixes = [""] unless prefixes.present?
            prefixes = (prefixes+self.prefixes).uniq if prefixes.is_a?(Array)
          end
          @view_paths.exists?(*args_for_lookup(name, prefixes, partial, keys, options))
        end
        alias :template_exists? :exists?
      end
    end
  end
end