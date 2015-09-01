require 'open-uri'
require 'net/https'

module Net
  class HTTP
    alias_method :original_use_ssl=, :use_ssl=

    # fix ssl for facebook connection
    def use_ssl=(flag)
      if @address.include?("facebook.com")
        self.ca_file =  File.join($camaleon_engine_dir, 'lib/ca-bundle.crt').to_s
        self.verify_mode = OpenSSL::SSL::VERIFY_PEER
        self.original_use_ssl = flag

      else # original method
        flag = flag ? true : false
        if started? and @use_ssl != flag
          raise IOError, "use_ssl value changed, but session already started"
        end
        @use_ssl = flag
      end

    end
  end
end