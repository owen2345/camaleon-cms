=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
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
