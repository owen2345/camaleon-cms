# customizable cache path for cache inline
module ActiveSupport
  module Cache
    class FileStore < Store
      attr_reader :cache_path
      attr_writer :cache_path
    end
  end
end
