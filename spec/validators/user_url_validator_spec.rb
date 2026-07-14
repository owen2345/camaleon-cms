# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CamaleonCms::UserUrlValidator do
  include StubRequests

  describe '#validate' do
    it 'returns true for legitimate URL' do
      expect(described_class.validate('https://gitlab.com/foo/foo.git')).to be(true)
    end

    it 'returns error for invalid URL' do
      expect(described_class.validate('http://:8080')).to eql([I18n.t('camaleon_cms.admin.validate.url')])
      expect(described_class.validate(nil)).to eql([I18n.t('camaleon_cms.admin.validate.url')])
      expect(described_class.validate('http://1.1.1.1.1')).to eql([I18n.t('camaleon_cms.admin.validate.host_invalid')])

      expect(described_class.validate('http://1.1.1 ')).to eql([I18n.t('camaleon_cms.admin.validate.url')])

      expect(described_class.validate("http://1.1.1\x00garbage"))
        .to eql([I18n.t('camaleon_cms.admin.validate.html_tags')])

      expect(described_class.validate('http://192.168.1'))
        .to eql([I18n.t('camaleon_cms.admin.validate.no_local_net_requests')])
    end

    it 'returns error for URLs with a blank hostname' do
      expect(described_class.validate('http:///path')).to eql([I18n.t('camaleon_cms.admin.validate.host_invalid')])
      expect(described_class.validate('http://:8080/path')).to eql([I18n.t('camaleon_cms.admin.validate.host_invalid')])
    end

    it 'blocks too long hostnames' do
      expect(described_class.validate("https://example#{'a' * 1024}.com"))
        .to eql([I18n.t('camaleon_cms.admin.validate.hostname_long')])
    end

    it 'blocks URLs with a non-alphanumeric hostname' do
      expect(described_class.validate('ssh://-oProxyCommand=whoami/a'))
        .to eql([I18n.t('camaleon_cms.admin.validate.host_or_ip_invalid')])

      expect(described_class.validate('ssh://­oProxyCommand=whoami/a'))
        .to eql([I18n.t('camaleon_cms.admin.validate.host_or_ip_invalid')])

      stub_dns('ssh://ğitlab.com/a', ip_address: '93.184.216.34', port: 22)

      expect(described_class.validate('ssh://ğitlab.com/a')).to be(true)
    end

    it 'blocks bad localhost hostname' do
      expect(described_class.validate('https://localhost:65535/foo/foo.git'))
        .to include(I18n.t('camaleon_cms.admin.validate.no_localhost_requests'))
    end

    it 'blocks URLs with localhost IPs' do
      expect(described_class.validate('https://[0:0:0:0:0:0:0:0]/foo/foo.git'))
        .to include(I18n.t('camaleon_cms.admin.validate.no_localhost_requests'))
      expect(described_class.validate('https://0.0.0.0/foo/foo.git'))
        .to include(I18n.t('camaleon_cms.admin.validate.no_localhost_requests'))
      expect(described_class.validate('https://[::]/foo/foo.git'))
        .to include(I18n.t('camaleon_cms.admin.validate.no_localhost_requests'))
    end

    it 'blocks loopback IP URLs' do
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
          '255.255.255.255',
          '0377.0377.0377.0377',
          '0377.00000000377.00377.0000377',
          '0xff.0xff.0xff.0xff',
          '0xffffffff',
          '0xBaaaaaaaaaaaaaaaaffffffff',
          '255.255.255.255:65535',
          '4294967295',
          '[::ffff:ffff:ffff]',
          '[0000:0000:0000:0000:0000:ffff:ffff:ffff]'
        ]
      end

      let(:fake_domain) { 'www.fakedomain.fake' }

      shared_examples 'allows local requests' do |url_blocker_args|
        it 'does not block URLs from private networks' do
          local_ips.each do |ip|
            stub_domain_resolv(fake_domain, ip) do
              expect(described_class.validate("https://#{fake_domain}", **url_blocker_args)).to be(true)
            end

            expect(described_class.validate("https://#{ip}", **url_blocker_args)).to be(true)
          end
        end

        it 'allows localhost endpoints' do
          expect(described_class.validate('http://0.0.0.0', **url_blocker_args)).to be(true)
          expect(described_class.validate('http://localhost', **url_blocker_args)).to be(true)
          expect(described_class.validate('http://127.0.0.1', **url_blocker_args)).to be(true)
        end

        it 'allows loopback endpoints' do
          expect(described_class.validate('http://127.0.0.2', **url_blocker_args)).to be(true)
        end

        it 'allows IPv4 link-local endpoints' do
          expect(described_class.validate('http://169.254.169.254', **url_blocker_args)).to be(true)
          expect(described_class.validate('http://169.254.168.100', **url_blocker_args)).to be(true)
        end

        it 'allows IPv6 link-local endpoints' do
          expect(described_class.validate('http://[0:0:0:0:0:ffff:169.254.169.254]', **url_blocker_args)).to be(true)
          expect(described_class.validate('http://[::ffff:169.254.169.254]', **url_blocker_args)).to be(true)
          expect(described_class.validate('http://[::ffff:a9fe:a9fe]', **url_blocker_args)).to be(true)
          expect(described_class.validate('http://[0:0:0:0:0:ffff:169.254.168.100]', **url_blocker_args)).to be(true)
          expect(described_class.validate('http://[::ffff:169.254.168.100]', **url_blocker_args)).to be(true)
          expect(described_class.validate('http://[::ffff:a9fe:a864]', **url_blocker_args)).to be(true)
          expect(described_class.validate('http://[fe80::c800:eff:fe74:8]', **url_blocker_args)).to be(true)
        end

        it 'allows limited broadcast address 255.255.255.255 and variants' do
          allow(Addrinfo).to receive(:getaddrinfo).and_call_original
          limited_broadcast_address_variants.each do |variant|
            if variant == '0xBaaaaaaaaaaaaaaaaffffffff' && RUBY_PLATFORM.exclude?('darwin')
              allow(Addrinfo).to receive(:getaddrinfo).with(variant, 443, nil,
                                                            :STREAM).and_raise(SocketError)
            end

            result = described_class.validate("https://#{variant}", **url_blocker_args)

            if variant == '0xBaaaaaaaaaaaaaaaaffffffff' && RUBY_PLATFORM.exclude?('darwin')
              expect(result).to eql([I18n.t('camaleon_cms.admin.validate.host_invalid')])
              next
            end

            expect(result).to be(true)
          end
        end
      end

      context 'when true (default)' do
        it_behaves_like 'allows local requests', { allow_localhost: true, allow_local_network: true }
      end

      context 'when false' do
        it 'blocks URLs from private networks' do
          local_ips.each do |ip|
            stub_domain_resolv(fake_domain, ip) do
              expect(described_class.validate("https://#{fake_domain}", allow_local_network: false))
                .to include(I18n.t('camaleon_cms.admin.validate.no_local_net_requests'))
            end

            expect(described_class.validate("https://#{ip}", allow_local_network: false))
              .to include(I18n.t('camaleon_cms.admin.validate.no_local_net_requests'))
          end
        end

        it 'blocks URLs from shared address space' do
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
          allow(Addrinfo).to receive(:getaddrinfo).and_call_original
          limited_broadcast_address_variants.each do |variant|
            if variant == '0xBaaaaaaaaaaaaaaaaffffffff' && RUBY_PLATFORM.exclude?('darwin')
              allow(Addrinfo).to receive(:getaddrinfo).with(variant, 443, nil,
                                                            :STREAM).and_raise(SocketError)
            end

            result = described_class.validate("https://#{variant}", allow_local_network: false)

            if variant == '0xBaaaaaaaaaaaaaaaaffffffff' && RUBY_PLATFORM.exclude?('darwin')
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
        it 'blocks URLs with a non-alphanumeric username' do
          expect(described_class.validate('ssh://-oProxyCommand=whoami@example.com/a'))
            .to eql([I18n.t('camaleon_cms.admin.validate.username_alphanumeric')])

          expect(described_class.validate('ssh://­oProxyCommand=whoami@example.com/a'))
            .to eql([I18n.t('camaleon_cms.admin.validate.username_alphanumeric')])

          expect(described_class.validate('ssh://ğitlab@example.com/a')).to be(true)
        end
      end

      context 'when false' do
        it 'does not block URLs with a non-alphanumeric username' do
          expect(described_class.validate('ssh://-oProxyCommand=whoami@example.com/a', enforce_user: false))
            .to be(true)

          expect(described_class.validate('ssh://­oProxyCommand=whoami@example.com/a', enforce_user: false))
            .to be(true)

          expect(described_class.validate('ssh://ğitlab@example.com/a', enforce_user: false)).to be(true)
        end
      end
    end

    it 'blocks URLs with invalid ip address' do
      expect(described_class.validate('http://8.8.8.8.8')).to eql([I18n.t('camaleon_cms.admin.validate.host_invalid')])
    end

    it 'blocks URLs whose hostname cannot be resolved' do
      allow(Addrinfo).to receive(:getaddrinfo).with('foobar.invalid.', 443, nil, :STREAM).and_raise(SocketError)
      expect(described_class.validate('https://foobar.invalid'))
        .to eql([I18n.t('camaleon_cms.admin.validate.host_invalid')])
    end

    describe '#resolved_ip' do
      it 'is nil before any validation' do
        expect(described_class.new.resolved_ip).to be_nil
      end

      it 'is populated with the resolved IP address after a successful validate call' do
        stub_dns('https://provider.example.com/services/sca', ip_address: '93.184.216.34')
        validator = described_class.new
        validator.validate('https://provider.example.com/services/sca')

        expect(validator.resolved_ip).to eq('93.184.216.34')
      end

      it 'is still set even when validation fails due to an unsafe (link-local) URL' do
        validator = described_class.new
        result = validator.validate('https://169.254.169.254/')

        expect(result).to include(I18n.t('camaleon_cms.admin.validate.no_link_local_net_requests'))
        expect(validator.resolved_ip).to eq('169.254.169.254')
      end

      it 'remains nil when validation fails due to an invalid URL' do
        validator = described_class.new
        validator.validate(nil)

        expect(validator.resolved_ip).to be_nil
      end
    end

    describe '#valid_ip? (via validate_hostname)' do
      it 'accepts valid IPv4 addresses as hostnames' do
        expect(described_class.validate('https://1.2.3.4/')).to be(true)
      end

      it 'accepts valid IPv6 addresses as hostnames' do
        expect(described_class.validate('https://[2001:db8::1]/')).to be(true)
      end

      it "doesn't accept subnet paths (treated as URL path), only accepting a bare IP as a valid hostname" do
        expect(described_class.validate('https://192.168.1.0/24'))
          .to include(I18n.t('camaleon_cms.admin.validate.no_local_net_requests'))
      end

      it 'rejects out-of-range IP octets (999.999.999.999) as an unresolvable host' do
        expect(described_class.validate('https://999.999.999.999/'))
          .to include(I18n.t('camaleon_cms.admin.validate.host_invalid'))
      end

      it 'rejects hostnames with more than four decimal octets (e.g. 1.2.3.4.5)' do
        expect(described_class.validate('https://1.2.3.4.5/'))
          .to include(I18n.t('camaleon_cms.admin.validate.host_invalid'))
      end

      it 'rejects short out-of-range decimal dotted hostnames (e.g. 999.999)' do
        allow(Addrinfo).to receive(:getaddrinfo).with('999.999', 443, nil, :STREAM).and_raise(SocketError)
        expect(described_class.validate('https://999.999/'))
          .to include(I18n.t('camaleon_cms.admin.validate.host_invalid'))
      end

      it 'rejects strings with trailing spaces that look like IPs' do
        expect(described_class.validate('https://1.2.3.4 /')).to eql([I18n.t('camaleon_cms.admin.validate.url')])
      end
    end

    describe '#validate with resolve: false' do
      it 'allows legitimate external URLs' do
        expect(described_class.new.validate('https://example.com/callback', resolve: false)).to be(true)
      end

      it 'allows custom scheme deep-link URLs' do
        expect(described_class.new.validate('authenticator://oauth/redirect', resolve: false)).to be(true)
        expect(described_class.new.validate('bankapp://callback?token=abc', resolve: false)).to be(true)
      end

      it 'rejects invalid URLs' do
        expect(described_class.new.validate(nil, resolve: false)).to eql([I18n.t('camaleon_cms.admin.validate.url')])
        expect(described_class.new.validate('', resolve: false)).to eql([I18n.t('camaleon_cms.admin.validate.url')])
        expect(described_class.new.validate('http://:8080',
                                            resolve: false)).to eql([I18n.t('camaleon_cms.admin.validate.url')])
      end

      it 'rejects URLs with a non-alphanumeric hostname' do
        expect(described_class.new.validate('ssh://-oProxyCommand=whoami/a', resolve: false))
          .to eql([I18n.t('camaleon_cms.admin.validate.host_or_ip_invalid')])

        expect(described_class.new.validate('ssh://­oProxyCommand=whoami/a', resolve: false))
          .to eql([I18n.t('camaleon_cms.admin.validate.host_or_ip_invalid')])
      end

      it 'rejects invalid decimal IPv4 hostnames' do
        expect(described_class.new.validate('http://256.1.1.1/callback', resolve: false))
          .to eql([I18n.t('camaleon_cms.admin.validate.host_invalid')])
        expect(described_class.new.validate('http://192.168.1.256/callback', resolve: false))
          .to eql([I18n.t('camaleon_cms.admin.validate.host_invalid')])
      end

      it 'rejects URLs with HTML/JS tags' do
        result = described_class.new.validate('http://example.com/<script>alert(1)</script>', resolve: false)
        expect(result).to eql([I18n.t('camaleon_cms.admin.validate.html_tags')])
      end

      it 'returns category-specific error messages for blocked URLs' do
        expect(described_class.new.validate('http://192.168.1.1/callback', resolve: false))
          .to eql([I18n.t('camaleon_cms.admin.validate.no_local_net_requests')])
        expect(described_class.new.validate('http://127.0.0.1/callback', resolve: false))
          .to eql([I18n.t('camaleon_cms.admin.validate.no_loopback_requests')])
        expect(described_class.new.validate('http://localhost/callback', resolve: false))
          .to eql([I18n.t('camaleon_cms.admin.validate.no_localhost_requests')])
        expect(described_class.new.validate('http://169.254.169.254/callback', resolve: false))
          .to eql([I18n.t('camaleon_cms.admin.validate.no_link_local_net_requests')])
        expect(described_class.new.validate('http://[::]/callback', resolve: false))
          .to eql([I18n.t('camaleon_cms.admin.validate.no_localhost_requests')])
      end

      it 'allows nil hostname URLs without raising' do
        expect(described_class.new.validate('authenticator://oauth/callback', resolve: false))
          .to be(true)
      end

      it 'does not set resolved_ip (no DNS resolution performed)' do
        validator = described_class.new
        validator.validate('https://example.com/callback', resolve: false)
        expect(validator.resolved_ip).to be_nil
      end
    end

    describe 'reject_path_traversal' do
      it 'detects ../ in URL path when enabled' do
        expect(described_class.validate('http://example.com/../etc/passwd', reject_path_traversal: true))
          .to eql([I18n.t('camaleon_cms.admin.validate.path_traversal')])
      end

      it 'detects URL-encoded %2e%2e in URL path when enabled' do
        expect(described_class.validate('http://example.com/%2e%2e/etc/passwd', reject_path_traversal: true))
          .to eql([I18n.t('camaleon_cms.admin.validate.path_traversal')])
      end

      it 'passes normal URLs when path traversal detection is enabled' do
        expect(described_class.validate('http://example.com/images/photo.jpg', reject_path_traversal: true))
          .to be(true)
      end

      it 'does not check path traversal when option is not set (default)' do
        expect(described_class.validate('http://example.com/../etc/passwd'))
          .to be(true)
      end
    end

    describe 'when CAMALEON_SKIP_URL_VALIDATION is set' do
      before { allow(ENV).to receive(:[]).and_call_original }

      it 'bypasses all SSRF checks and returns true' do
        allow(ENV).to receive(:[]).with('CAMALEON_SKIP_URL_VALIDATION').and_return('1')
        expect(described_class.validate('http://127.0.0.1')).to be(true)
        expect(described_class.validate('http://169.254.169.254')).to be(true)
      end

      it 'bypasses the HTTPS/SSRF checks in validate_external_https' do
        allow(ENV).to receive(:[]).with('CAMALEON_SKIP_URL_VALIDATION').and_return('1')
        expect(described_class.validate_external_https('http://localhost:3000')).to be(true)
        expect(described_class.validate_external_https('http://169.254.169.254/services/sca')).to be(true)
      end
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
      # The validator's hostname_for_resolution adds a trailing dot for domain-like hostnames
      resolved_domain = domain.match?(/\.[a-zA-Z]/) ? "#{domain}." : domain
      allow(Addrinfo).to receive(:getaddrinfo).with(resolved_domain, port, any_args).and_return([address])
      allow(address).to receive(:ipv6_v4mapped?).and_return(false)

      yield

      allow(Addrinfo).to receive(:getaddrinfo).and_call_original
    end
  end

  describe '.validate_external_https' do
    it 'allows resolvable external HTTPS URLs' do
      url = 'https://provider.example.com/services/sca'
      stub_dns(url, ip_address: '93.184.216.34')

      expect(described_class.validate_external_https(url)).to be(true)
    end

    it 'rejects non-HTTPS URLs' do
      url = 'http://provider.example.com/services/sca'
      stub_dns(url, ip_address: '93.184.216.34', port: 80)

      expect(described_class.validate_external_https(url))
        .to eql([I18n.t('camaleon_cms.admin.validate.https_only_url')])
    end

    it 'rejects URLs without a host' do
      expect(described_class.validate_external_https('123456789')).to eql([I18n.t('camaleon_cms.admin.validate.url')])
    end

    it 'rejects link-local URLs' do
      expect(described_class.validate_external_https('https://169.254.169.254/services/sca'))
        .to eql([I18n.t('camaleon_cms.admin.validate.no_link_local_net_requests')])
    end

    it 'populates resolved_ip after a successful validation, enabling IP pinning by callers' do
      url = 'https://provider.example.com/services/sca'
      stub_dns(url, ip_address: '93.184.216.34')

      validator = described_class.new
      result = validator.validate_external_https(url)

      expect(result).to be(true)
      expect(validator.resolved_ip).to eq('93.184.216.34')
    end
  end
end
