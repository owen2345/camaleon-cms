require 'open-uri'
require 'net/https'

module Net
  class HTTP
    alias_method :original_use_ssl=, :use_ssl=

    def use_ssl=(flag)
      self.verify_mode = OpenSSL::SSL::VERIFY_PEER
      self.original_use_ssl = flag

      if @address.to_s.include? 'amazonaws.com'
        self.ca_file = nil
        self.ca_path = nil
        self.cert_store = nil
      else
        self.ca_file = Rails.root.join('lib/ca-bundle.crt').to_s
      end
    end
  end
end
