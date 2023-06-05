# frozen_string_literal: true

module StubRequests
  def stub_dns(url, ip_address:, port: 80)
    url = parse_url(url)
    socket = Socket.sockaddr_in(port, ip_address)
    addr = Addrinfo.new(socket)

    # See CamaleonCms::UserUrlValidator
    allow(Addrinfo).to receive(:getaddrinfo).with(url.hostname, url.port || port, nil, :STREAM).and_return([addr])
  end

  private

  def parse_url(url)
    url.is_a?(URI) ? url : Addressable::URI.parse(url)
  end
end
