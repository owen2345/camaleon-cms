# frozen_string_literal: true

module StubRequests
  def stub_dns(url, ip_address:, port: 443)
    url = parse_url(url)
    socket = Socket.sockaddr_in(port, ip_address)
    addr = Addrinfo.new(socket)

    hostname = url.hostname
    # Matches the same hostname_for_resolution logic used in the validator
    # (adds a trailing dot for domain-like hostnames to avoid search domain expansion)
    stub_hostname = if hostname.present? && !valid_ip_string?(hostname) && hostname.match?(/\.[a-zA-Z]/)
                      "#{hostname}."
                    else
                      hostname
                    end

    allow(Addrinfo).to receive(:getaddrinfo).with(stub_hostname, url.port || port, nil, :STREAM).and_return([addr])
  end

  private

  def parse_url(url)
    url.is_a?(URI) ? url : Addressable::URI.parse(url)
  end

  def valid_ip_string?(hostname)
    Resolv::IPv4::Regex.match?(hostname) || Resolv::IPv6::Regex.match?(hostname)
  end
end
