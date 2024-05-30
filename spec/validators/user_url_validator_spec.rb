# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CamaleonCms::UserUrlValidator do
  include StubRequests

  describe '#validate' do
    it 'returns true for legitimate URL' do
      expect(described_class.validate('https://gitlab.com/foo/foo.git')).to eql(true)
    end

    it 'returns error for invalid URL' do
      expect(described_class.validate('http://:8080')).to eql([I18n.t('camaleon_cms.admin.validate.url')])
      expect(described_class.validate(nil)).to eql([I18n.t('camaleon_cms.admin.validate.url')])
      expect(described_class.validate('http://1.1.1.1.1')).to eql([I18n.t('camaleon_cms.admin.validate.host_invalid')])
    end

    it 'blocks too long hostnames' do
      expect(described_class.validate("https://example#{'a' * 1024}.com"))
        .to eql([I18n.t('camaleon_cms.admin.validate.hostname_long')])
    end

    it 'blocks urls with a non-alphanumeric hostname' do
      expect(described_class.validate('ssh://-oProxyCommand=whoami/a'))
        .to eql([I18n.t('camaleon_cms.admin.validate.host_or_ip_invalid')])

      # The leading character here is a Unicode "soft hyphen"
      expect(described_class.validate('ssh://­oProxyCommand=whoami/a'))
        .to eql([I18n.t('camaleon_cms.admin.validate.host_or_ip_invalid')])

      # Unicode alphanumerics are allowed, so stubbing the DNS here just because there is no such host
      stub_dns('ssh://ğitlab.com/a', ip_address: '93.184.216.34', port: 22)

      expect(described_class.validate('ssh://ğitlab.com/a')).to eql(true)
    end

    it 'blocks bad localhost hostname' do
      expect(described_class.validate('https://localhost:65535/foo/foo.git'))
        .to include(I18n.t('camaleon_cms.admin.validate.no_localhost_requests'))
    end

    it 'blocks urls with localhost IPs' do
      expect(described_class.validate('https://[0:0:0:0:0:0:0:0]/foo/foo.git'))
        .to include(I18n.t('camaleon_cms.admin.validate.no_localhost_requests'))
      expect(described_class.validate('https://0.0.0.0/foo/foo.git'))
        .to include(I18n.t('camaleon_cms.admin.validate.no_localhost_requests'))
      expect(described_class.validate('https://[::]/foo/foo.git'))
        .to include(I18n.t('camaleon_cms.admin.validate.no_localhost_requests'))
    end

    it 'blocks loopback IP urls' do
      expect(described_class.validate('https://127.0.0.2/foo/foo.git'))
        .to include(I18n.t('camaleon_cms.admin.validate.no_loopback_requests'))
      expect(described_class.validate('https://127.0.0.1/foo/foo.git'))
        .to include(I18n.t('camaleon_cms.admin.validate.no_loopback_requests'))
      expect(described_class.validate('https://[::1]/foo/foo.git'))
        .to include(I18n.t('camaleon_cms.admin.validate.no_loopback_requests'))
    end

    it 'blocks alternative version of 127.0.0.1 (0177.1)' do
      expect(described_class.validate('https://0177.1:65535/foo/foo.git'))
        .to include(I18n.t('camaleon_cms.admin.validate.no_localhost_requests'))
    end

    it 'blocks alternative version of 127.0.0.1 (017700000001)' do
      expect(described_class.validate('https://017700000001:65535/foo/foo.git'))
        .to include(I18n.t('camaleon_cms.admin.validate.no_localhost_requests'))
    end

    it 'blocks alternative version of 127.0.0.1 (0x7f.1)' do
      expect(described_class.validate('https://0x7f.1:65535/foo/foo.git'))
        .to include(I18n.t('camaleon_cms.admin.validate.no_localhost_requests'))
    end

    it 'blocks alternative version of 127.0.0.1 (0x7f.0.0.1)' do
      expect(described_class.validate('https://0x7f.0.0.1:65535/foo/foo.git'))
        .to include(I18n.t('camaleon_cms.admin.validate.no_localhost_requests'))
    end

    it 'blocks alternative version of 127.0.0.1 (0x7f.0x0.0x0.0x1)' do
      expect(described_class.validate('https://0x7f.0x0.0x0.0x1:65535/foo/foo.git'))
        .to include(I18n.t('camaleon_cms.admin.validate.no_localhost_requests'))
    end

    it 'blocks alternative version of 127.0.0.1 (0x7f000001)' do
      expect(described_class.validate('https://0x7f000001:65535/foo/foo.git'))
        .to include(I18n.t('camaleon_cms.admin.validate.no_localhost_requests'))
    end

    it 'blocks octal encoding version of 127.0.0.1 (0177.0.0.01)' do
      expect(described_class.validate('https://0177.1/foo/foo.git'))
        .to include(I18n.t('camaleon_cms.admin.validate.no_localhost_requests'))
    end

    it 'blocks dword encoding version of 127.0.0.1 (2130706433)' do
      expect(described_class.validate('https://2130706433:65535/foo/foo.git'))
        .to include(I18n.t('camaleon_cms.admin.validate.no_localhost_requests'))
    end

    it 'blocks alternative version of 127.0.0.1 (127.000.000.001)' do
      expect(described_class.validate('https://127.000.000.001:65535/foo/foo.git'))
        .to include(I18n.t('camaleon_cms.admin.validate.no_localhost_requests'))
    end

    it 'blocks alternative version of 127.0.0.1 (127.0.1)' do
      expect(described_class.validate('https://127.0.1:65535/foo/foo.git'))
        .to include(I18n.t('camaleon_cms.admin.validate.no_localhost_requests'))
    end

    context 'with ipv6 mapped address' do
      it 'blocks localhost IPs' do
        expect(described_class.validate('https://[0:0:0:0:0:ffff:0.0.0.0]/foo/foo.git'))
          .to include(I18n.t('camaleon_cms.admin.validate.no_localhost_requests'))
        expect(described_class.validate('https://[::ffff:0.0.0.0]/foo/foo.git'))
          .to include(I18n.t('camaleon_cms.admin.validate.no_localhost_requests'))
        expect(described_class.validate('https://[::ffff:0:0]/foo/foo.git'))
          .to include(I18n.t('camaleon_cms.admin.validate.no_localhost_requests'))
      end

      it 'blocks loopback IPs' do
        expect(described_class.validate('https://[0:0:0:0:0:ffff:127.0.0.1]/foo/foo.git'))
          .to include(I18n.t('camaleon_cms.admin.validate.no_loopback_requests'))
        expect(described_class.validate('https://[::ffff:127.0.0.1]/foo/foo.git'))
          .to include(I18n.t('camaleon_cms.admin.validate.no_loopback_requests'))
        expect(described_class.validate('https://[::ffff:7f00:1]/foo/foo.git'))
          .to include(I18n.t('camaleon_cms.admin.validate.no_loopback_requests'))
        expect(described_class.validate('https://[0:0:0:0:0:ffff:127.0.0.2]/foo/foo.git'))
          .to include(I18n.t('camaleon_cms.admin.validate.no_loopback_requests'))
        expect(described_class.validate('https://[::ffff:127.0.0.2]/foo/foo.git'))
          .to include(I18n.t('camaleon_cms.admin.validate.no_loopback_requests'))
        expect(described_class.validate('https://[::ffff:7f00:2]/foo/foo.git'))
          .to include(I18n.t('camaleon_cms.admin.validate.no_loopback_requests'))
      end
    end

    describe 'allow_local_network' do
      let(:shared_address_space_ips) { %w[100.64.0.0 100.64.127.127 100.64.255.255] }

      let(:local_ips) do
        %w[
          192.168.1.2
          [0:0:0:0:0:ffff:192.168.1.2]
          [::ffff:c0a8:102]
          10.0.0.2
          [0:0:0:0:0:ffff:10.0.0.2]
          [::ffff:a00:2] 172.16.0.2
          [0:0:0:0:0:ffff:172.16.0.2]
          [::ffff:ac10:20]
          [feef::1]
          [fee2::]
          [fc00:bf8b:e62c:abcd:abcd:aaaa:aaaa:aaaa]
        ]
      end

      let(:limited_broadcast_address_variants) do
        [
          '255.255.255.255', # "normal"  dotted decimal
          '0377.0377.0377.0377', # Octal
          '0377.00000000377.00377.0000377', # Still octal
          '0xff.0xff.0xff.0xff', # hex
          '0xffffffff', # still hex
          '0xBaaaaaaaaaaaaaaaaffffffff', # padded hex
          '255.255.255.255:65535', # with a port
          '4294967295', # as an integer / dword
          '[::ffff:ffff:ffff]', # short IPv6
          '[0000:0000:0000:0000:0000:ffff:ffff:ffff]' # long IPv6
        ]
      end

      let(:fake_domain) { 'www.fakedomain.fake' }

      shared_examples 'allows local requests' do |url_blocker_args|
        it 'does not block urls from private networks' do
          local_ips.each do |ip|
            stub_domain_resolv(fake_domain, ip) do
              expect(described_class.validate("https://#{fake_domain}", **url_blocker_args)).to eql(true)
            end

            expect(described_class.validate("https://#{ip}", **url_blocker_args)).to eql(true)
          end
        end

        it 'allows localhost endpoints' do
          expect(described_class.validate('http://0.0.0.0', **url_blocker_args)).to eql(true)
          expect(described_class.validate('http://localhost', **url_blocker_args)).to eql(true)
          expect(described_class.validate('http://127.0.0.1', **url_blocker_args)).to eql(true)
        end

        it 'allows loopback endpoints' do
          expect(described_class.validate('http://127.0.0.2', **url_blocker_args)).to eql(true)
        end

        it 'allows IPv4 link-local endpoints' do
          expect(described_class.validate('http://169.254.169.254', **url_blocker_args)).to eql(true)
          expect(described_class.validate('http://169.254.168.100', **url_blocker_args)).to eql(true)
        end

        it 'allows IPv6 link-local endpoints' do
          expect(described_class.validate('http://[0:0:0:0:0:ffff:169.254.169.254]', **url_blocker_args)).to eql(true)
          expect(described_class.validate('http://[::ffff:169.254.169.254]', **url_blocker_args)).to eql(true)
          expect(described_class.validate('http://[::ffff:a9fe:a9fe]', **url_blocker_args)).to eql(true)
          expect(described_class.validate('http://[0:0:0:0:0:ffff:169.254.168.100]', **url_blocker_args)).to eql(true)
          expect(described_class.validate('http://[::ffff:169.254.168.100]', **url_blocker_args)).to eql(true)
          expect(described_class.validate('http://[::ffff:a9fe:a864]', **url_blocker_args)).to eql(true)
          expect(described_class.validate('http://[fe80::c800:eff:fe74:8]', **url_blocker_args)).to eql(true)
        end

        it 'allows limited broadcast address 255.255.255.255 and variants' do
          limited_broadcast_address_variants.each do |variant|
            result = described_class.validate("https://#{variant}", **url_blocker_args)

            # The padded hex version is a valid URL on Mac but not on Ubuntu.
            if variant == '0xBaaaaaaaaaaaaaaaaffffffff' && (/darwin/ =~ RUBY_PLATFORM).nil? # not MacOS
              expect(result).to eql([I18n.t('camaleon_cms.admin.validate.host_invalid')])
              next
            end

            expect(result).to eql(true)
          end
        end
      end

      context 'when true (default)' do
        it_behaves_like 'allows local requests', { allow_localhost: true, allow_local_network: true }
      end

      context 'when false' do
        it 'blocks urls from private networks' do
          local_ips.each do |ip|
            stub_domain_resolv(fake_domain, ip) do
              expect(described_class.validate("https://#{fake_domain}", allow_local_network: false))
                .to include(I18n.t('camaleon_cms.admin.validate.no_local_net_requests'))
            end

            expect(described_class.validate("https://#{ip}", allow_local_network: false))
              .to include(I18n.t('camaleon_cms.admin.validate.no_local_net_requests'))
          end
        end

        it 'blocks urls from shared address space' do
          shared_address_space_ips.each do |ip|
            stub_domain_resolv(fake_domain, ip) do
              expect(described_class.validate("https://#{fake_domain}", allow_local_network: false))
                .to include(I18n.t('camaleon_cms.admin.validate.no_shared_address_requests'))
            end

            expect(described_class.validate("https://#{ip}", allow_local_network: false))
              .to include(I18n.t('camaleon_cms.admin.validate.no_shared_address_requests'))
          end
        end

        it 'blocks IPv4 link-local endpoints' do
          expect(described_class.validate('http://169.254.169.254', allow_local_network: false))
            .to eql([I18n.t('camaleon_cms.admin.validate.no_link_local_net_requests')])
          expect(described_class.validate('http://169.254.168.100', allow_local_network: false))
            .to eql([I18n.t('camaleon_cms.admin.validate.no_link_local_net_requests')])
        end

        it 'blocks IPv6 link-local endpoints' do
          expect(described_class.validate('http://[0:0:0:0:0:ffff:169.254.169.254]', allow_local_network: false))
            .to eql([I18n.t('camaleon_cms.admin.validate.no_link_local_net_requests')])
          expect(described_class.validate('http://[::ffff:169.254.169.254]', allow_local_network: false))
            .to eql([I18n.t('camaleon_cms.admin.validate.no_link_local_net_requests')])
          expect(described_class.validate('http://[::ffff:a9fe:a9fe]', allow_local_network: false))
            .to eql([I18n.t('camaleon_cms.admin.validate.no_link_local_net_requests')])
          expect(described_class.validate('http://[0:0:0:0:0:ffff:169.254.168.100]', allow_local_network: false))
            .to eql([I18n.t('camaleon_cms.admin.validate.no_link_local_net_requests')])
          expect(described_class.validate('http://[::ffff:169.254.168.100]', allow_local_network: false))
            .to eql([I18n.t('camaleon_cms.admin.validate.no_link_local_net_requests')])
          expect(described_class.validate('http://[::ffff:a9fe:a864]', allow_local_network: false))
            .to eql([I18n.t('camaleon_cms.admin.validate.no_link_local_net_requests')])
          expect(described_class.validate('http://[fe80::c800:eff:fe74:8]', allow_local_network: false))
            .to eql([I18n.t('camaleon_cms.admin.validate.no_link_local_net_requests')])
        end

        it 'blocks limited broadcast address 255.255.255.255 and variants' do
          limited_broadcast_address_variants.each do |variant|
            result = described_class.validate("https://#{variant}", allow_local_network: false)

            # The padded hex version, is a valid URL on Mac but not on Ubuntu.
            if variant == '0xBaaaaaaaaaaaaaaaaffffffff' && (/darwin/ =~ RUBY_PLATFORM).nil? # not MacOS
              expect(result).to eql([I18n.t('camaleon_cms.admin.validate.host_invalid')])
              next
            end

            expect(result).to eql([I18n.t('camaleon_cms.admin.validate.no_limited_broadcast_address_requests')])
          end
        end
      end
    end

    describe 'enforce_user' do
      context 'when true (default)' do
        it 'blocks urls with a non-alphanumeric username' do
          expect(described_class.validate('ssh://-oProxyCommand=whoami@example.com/a'))
            .to eql([I18n.t('camaleon_cms.admin.validate.username_alphanumeric')])

          # The leading character here is a Unicode "soft hyphen"
          expect(described_class.validate('ssh://­oProxyCommand=whoami@example.com/a'))
            .to eql([I18n.t('camaleon_cms.admin.validate.username_alphanumeric')])

          # Unicode alphanumerics are allowed
          expect(described_class.validate('ssh://ğitlab@example.com/a')).to eql(true)
        end
      end

      context 'when true' do
        it 'does not block urls with a non-alphanumeric username' do
          expect(described_class.validate('ssh://-oProxyCommand=whoami@example.com/a', enforce_user: false))
            .to eql(true)

          # The leading character here is a Unicode "soft hyphen"
          expect(described_class.validate('ssh://­oProxyCommand=whoami@example.com/a', enforce_user: false))
            .to eql(true)

          # Unicode alphanumerics are allowed
          expect(described_class.validate('ssh://ğitlab@example.com/a', enforce_user: false)).to eql(true)
        end
      end
    end

    it 'blocks urls with invalid ip address' do
      expect(described_class.validate('http://8.8.8.8.8')).to eql([I18n.t('camaleon_cms.admin.validate.host_invalid')])
    end

    it 'blocks urls whose hostname cannot be resolved' do
      expect(described_class.validate('https://foobar.x')).to eql([I18n.t('camaleon_cms.admin.validate.host_invalid')])
    end

    def stub_domain_resolv(domain, ip, port = 443)
      address = instance_double(Addrinfo,
                                ip_address: ip,
                                ipv4_private?: true,
                                ipv6_linklocal?: false,
                                ipv4_loopback?: false,
                                ipv6_loopback?: false,
                                ipv4?: false,
                                ip_port: port)
      allow(Addrinfo).to receive(:getaddrinfo).with(domain, port, any_args).and_return([address])
      allow(address).to receive(:ipv6_v4mapped?).and_return(false)

      yield

      allow(Addrinfo).to receive(:getaddrinfo).and_call_original
    end
  end
end
