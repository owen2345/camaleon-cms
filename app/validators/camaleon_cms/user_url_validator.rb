# frozen_string_literal: true

# Copyright (c) 2011-present GitLab B.V.
#
# See https://gitlab.com/gitlab-org/gitlab/-/blob/master/lib/gitlab/url_blocker.rb
#
# Portions of this software are licensed under the "MIT Expat" license as defined below.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

require 'ipaddr'
require 'resolv'
require 'addressable/uri'

module CamaleonCms
  class UserUrlValidator
    HTTPS_SCHEME = 'https'
    LOCAL_IPS = %w[0.0.0.0 ::].freeze
    LINK_LOCAL_NETMASK  = IPAddr.new('169.254.0.0/16').freeze
    SHARED_ADDR_NETMASK = IPAddr.new('100.64.0.0/10').freeze
    IPV6_SITELOCAL      = IPAddr.new('fec0::/10').freeze
    IPV6_UNIQUE_LOCAL   = IPAddr.new('fc00::/7').freeze

    def self.validate(...)
      new.validate(...)
    end

    def self.validate_external_https(...)
      new.validate_external_https(...)
    end

    attr_reader :resolved_ip

    def initialize
      @errors = []
      @resolved_ip = nil
    end

    # Validates the given url according to the constraints specified by the received arguments.
    #
    # allow_localhost - Registers error if URL resolves to a localhost IP address and argument is false.
    # allow_local_network - Registers error if URL resolves to a link-local address and argument is false.
    # enforce_user - Registers error if URL user doesn't start with alphanumeric characters and argument is true.
    # enforce_sanitizing - Registers error if URL includes any HTML/CSS/JS tags and argument is true.
    # resolve - When true (default), performs DNS resolution to check the IP.
    #           When false, only validates URL structure and checks IP literals statically
    #           (no DNS resolution, allowing unresolvable hostnames like custom scheme URLs).
    # reject_path_traversal - When true, checks if URI path contains path traversal sequences.
    #
    # Returns an array with error messages, or true if valid.
    def validate(url, allow_localhost: false, allow_local_network: false, enforce_user: true, enforce_sanitizing: true,
                 resolve: true, reject_path_traversal: false)
      return true if skip_validation?
      return invalid_url if url.blank?

      return invalid_url unless (uri = parse_url(url))

      validate_uri(uri: uri, enforce_sanitizing: enforce_sanitizing, enforce_user: enforce_user)

      validate_path_traversal(uri) if reject_path_traversal
      return @errors if @errors.any?

      if resolve
        return @errors if @errors.any?

        address_info = get_address_info(uri)
        return @errors if @errors.any?

        @resolved_ip = address_info.first&.ip_address

        validate_local_request(
          address_info: address_info,
          allow_localhost: allow_localhost,
          allow_local_network: allow_local_network
        )
      else
        validate_static_ip(uri.hostname, allow_localhost: allow_localhost, allow_local_network: allow_local_network)
      end

      @errors.empty? || @errors
    end

    def validate_external_https(url)
      return true if skip_validation?

      uri = parse_url(url)
      return [I18n.t('camaleon_cms.admin.validate.url')] if uri.nil? || uri.scheme.blank? || uri.hostname.blank?
      return [I18n.t('camaleon_cms.admin.validate.https_only_url')] unless uri.scheme&.downcase == HTTPS_SCHEME

      validate(uri, allow_localhost: false, allow_local_network: false)
    end

    private

    def skip_validation?
      ENV['CAMALEON_SKIP_URL_VALIDATION'].present?
    end

    def validate_uri(uri:, enforce_sanitizing:, enforce_user:)
      validate_html_tags(uri) if enforce_sanitizing

      validate_user(uri.user) if enforce_user
      validate_hostname(uri.hostname)
    end

    def get_address_info(uri)
      return @errors << I18n.t('camaleon_cms.admin.validate.host_invalid') if uri.hostname.blank?

      Addrinfo.getaddrinfo(hostname_for_resolution(uri.hostname), get_port(uri), nil, :STREAM).map do |addr|
        addr.ipv6_v4mapped? ? addr.ipv6_to_ipv4 : addr
      end
    rescue SocketError
      if valid_ip?(uri.hostname)
        addr = Addrinfo.new(Socket.pack_sockaddr_in(get_port(uri), uri.hostname))
        [addr.ipv6_v4mapped? ? addr.ipv6_to_ipv4 : addr]
      else
        @errors << I18n.t('camaleon_cms.admin.validate.host_invalid')
      end
    rescue ArgumentError => e
      @errors << I18n.t('camaleon_cms.admin.validate.hostname_long') if e.message.include?('hostname too long')

      @errors << "#{e.message}: #{I18n.t('camaleon_cms.admin.validate.url')}" if @errors.blank?
    end

    def validate_local_request(address_info:, allow_localhost:, allow_local_network:)
      return if allow_local_network && allow_localhost

      unless allow_localhost
        validate_localhost(address_info)
        validate_loopback(address_info)
      end

      return if allow_local_network

      validate_local_network(address_info)
      validate_link_local(address_info)
      validate_shared_address(address_info)
      validate_limited_broadcast_address(address_info)
    end

    def get_port(uri)
      uri.port || uri.default_port
    end

    def hostname_for_resolution(hostname)
      return hostname if hostname.blank?
      return hostname if hostname.end_with?('.')
      return hostname if valid_ip?(hostname)
      return hostname unless hostname.match?(/\.[a-zA-Z]/)

      "#{hostname}."
    end

    def validate_html_tags(uri)
      uri_str = uri.to_s
      sanitized_uri = ActionController::Base.helpers.sanitize(uri_str, tags: [])
      @errors << I18n.t('camaleon_cms.admin.validate.html_tags') unless sanitized_uri == uri_str
    end

    def parse_url(url)
      invalid = nil
      uri = Addressable::URI.parse(url).tap do |parsed_url|
        invalid = true if multiline_blocked?(parsed_url)
      end
      return if invalid

      uri
    rescue Addressable::URI::InvalidURIError, URI::InvalidURIError
      nil
    end

    def multiline_blocked?(parsed_url)
      url = parsed_url.to_s

      return true if /[\n\r]/.match?(url)
      return false if %w[http https].include?(parsed_url.scheme&.downcase)

      CGI.unescape(url) =~ /[\n\r]/
    end

    def validate_user(value)
      return if value.blank?
      return if /\A\p{Alnum}/.match?(value)

      @errors << I18n.t('camaleon_cms.admin.validate.username_alphanumeric')
    end

    def validate_hostname(value)
      return if value.blank?
      return @errors << I18n.t('camaleon_cms.admin.validate.host_invalid') if invalid_decimal_ipv4_hostname?(value)
      return if valid_ip?(value)
      return if /\A\p{Alnum}/.match?(value)

      @errors << I18n.t('camaleon_cms.admin.validate.host_or_ip_invalid')
    end

    def invalid_decimal_ipv4_hostname?(value)
      return false unless /\A(?:0|[1-9]\d*)(?:\.(?:0|[1-9]\d*))+\z/.match?(value)

      # An all-numeric dotted hostname is only ever meant to be a dotted-quad
      # IPv4 literal. Reject it when it has too many octets or any out-of-range
      # octet (regardless of octet count) so an out-of-range shorthand form such
      # as 192.168.257 cannot slip through as a resolvable name. In-range
      # shorthand (e.g. 192.168.1) is left to the resolver/category checks.
      octets = value.split('.')
      octets.length > 4 || octets.any? { |octet| octet.to_i > 255 }
    end

    def valid_ip?(value)
      str = value.to_s
      return false if str.blank?
      return false if str.include?('/')
      return false unless Resolv::IPv4::Regex.match?(str) || Resolv::IPv6::Regex.match?(str)

      IPAddr.new(str)
      true
    rescue IPAddr::InvalidAddressError, IPAddr::AddressFamilyError
      false
    end

    def validate_localhost(addrs_info)
      return if (Socket.ip_address_list.map(&:ip_address).concat(LOCAL_IPS) & addrs_info.map(&:ip_address)).empty?

      @errors << I18n.t('camaleon_cms.admin.validate.no_localhost_requests')
    end

    def validate_loopback(addrs_info)
      return unless addrs_info.any? { |addr| loopback_ip?(ip_from_addrinfo(addr)) }

      @errors << I18n.t('camaleon_cms.admin.validate.no_loopback_requests')
    end

    def validate_local_network(addrs_info)
      return unless addrs_info.any? { |addr| local_network_ip?(ip_from_addrinfo(addr)) }

      @errors << I18n.t('camaleon_cms.admin.validate.no_local_net_requests')
    end

    def validate_link_local(addrs_info)
      return unless addrs_info.any? { |addr| link_local_ip?(ip_from_addrinfo(addr)) }

      @errors << I18n.t('camaleon_cms.admin.validate.no_link_local_net_requests')
    end

    def validate_shared_address(addrs_info)
      return unless addrs_info.any? { |addr| shared_address_ip?(ip_from_addrinfo(addr)) }

      @errors << I18n.t('camaleon_cms.admin.validate.no_shared_address_requests')
    end

    def validate_limited_broadcast_address(addrs_info)
      return unless addrs_info.any? { |addr| limited_broadcast_ip?(ip_from_addrinfo(addr)) }

      @errors << I18n.t('camaleon_cms.admin.validate.no_limited_broadcast_address_requests')
    end

    def validate_static_ip(hostname, allow_localhost:, allow_local_network:)
      return if hostname.blank?

      if !allow_localhost && (hostname.casecmp?('localhost') || hostname.casecmp?('localhost.localdomain'))
        @errors << I18n.t('camaleon_cms.admin.validate.no_localhost_requests')
        return
      end

      return unless valid_ip?(hostname)

      ip = IPAddr.new(hostname)
      ip = ip.native if ip.ipv4_mapped?

      validate_static_localhost(hostname, ip) unless allow_localhost
      return if allow_local_network

      validate_static_local_network(ip)
      validate_static_link_local(ip)
      validate_static_shared_address(ip)
      validate_static_limited_broadcast(ip)
    end

    def validate_static_localhost(hostname, ip)
      if hostname.in?(LOCAL_IPS) || ip.to_s == '::'
        @errors << I18n.t('camaleon_cms.admin.validate.no_localhost_requests')
      elsif ip.loopback?
        @errors << I18n.t('camaleon_cms.admin.validate.no_loopback_requests')
      end
    end

    def validate_static_local_network(ip)
      return unless local_network_ip?(ip)

      @errors << I18n.t('camaleon_cms.admin.validate.no_local_net_requests')
    end

    def validate_static_link_local(ip)
      return unless link_local_ip?(ip)

      @errors << I18n.t('camaleon_cms.admin.validate.no_link_local_net_requests')
    end

    def validate_static_shared_address(ip)
      return unless shared_address_ip?(ip)

      @errors << I18n.t('camaleon_cms.admin.validate.no_shared_address_requests')
    end

    def validate_static_limited_broadcast(ip)
      return unless limited_broadcast_ip?(ip)

      @errors << I18n.t('camaleon_cms.admin.validate.no_limited_broadcast_address_requests')
    end

    def validate_path_traversal(uri)
      # Fully percent-decode the path (so both %2e%2e and multiply-encoded forms
      # such as %252e%252e are caught) then look for actual ".." path segments.
      # Comparing uri.path to uri.normalized_path would instead flag legitimate
      # URLs whose encoding merely differs (e.g. %7E -> ~).
      decoded = uri.path.to_s
      5.times do
        unencoded = Addressable::URI.unencode(decoded)
        break if unencoded == decoded

        decoded = unencoded
      end
      return unless decoded.split(%r{[/\\]}).include?('..')

      @errors << I18n.t('camaleon_cms.admin.validate.path_traversal')
    end

    def ip_from_addrinfo(addr)
      ip = IPAddr.new(addr.ip_address)
      ip.ipv4_mapped? ? ip.native : ip
    end

    def loopback_ip?(ip)
      ip.loopback?
    end

    def local_network_ip?(ip)
      ip.private? || ipv6_sitelocal?(ip) || ipv6_unique_local?(ip)
    end

    def link_local_ip?(ip)
      ip.link_local? || LINK_LOCAL_NETMASK.include?(ip)
    end

    def shared_address_ip?(ip)
      SHARED_ADDR_NETMASK.include?(ip)
    end

    def limited_broadcast_ip?(ip)
      ip.to_s == '255.255.255.255'
    end

    def ipv6_sitelocal?(ip)
      IPV6_SITELOCAL.include?(ip)
    end

    def ipv6_unique_local?(ip)
      IPV6_UNIQUE_LOCAL.include?(ip)
    end

    def invalid_url
      @errors << I18n.t('camaleon_cms.admin.validate.url')
    end
  end
end
