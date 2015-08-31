require 'open-uri'
require 'net/https'

module Net
  class HTTP
    alias_method :original_use_ssl=, :use_ssl=

    # fix ssl for facebook connection
    def use_ssl=(flag)
      if @address.include?("facebook.com")
        self.ca_file = Rails.root.join('lib/ca-bundle.crt').to_s
        self.verify_mode = OpenSSL::SSL::VERIFY_PEER
        self.original_use_ssl = flag
      else
        super
      end
    end
  end
end
