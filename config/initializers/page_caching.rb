module ActionController
  module Caching
    module Pages extend ActiveSupport::Concern
      module ClassMethods
        # get page cache content
        def page_cache_get(path, extension = nil)
          return "" unless page_cache_exist?(path, extension)
          # File.read(path)
          path = page_cache_path(path, extension)
        end

        # verify if this cache is already saved
        def page_cache_exist?(path, extension = nil)
          path = page_cache_path(path, extension)
          File.exist?(path)
        end
      end

      def page_cache_exist?(path, extension = nil)
        self.class.page_cache_exist?(path, extension || get_cache_extension)
      end

      def page_cache_get(path, extension = nil)
        self.class.page_cache_get(path, extension || get_cache_extension)
      end

      private
      def get_cache_extension
        # request.accept_encoding.include?("gzip")?".html.gz":""
        nil
      end

    end
  end
end