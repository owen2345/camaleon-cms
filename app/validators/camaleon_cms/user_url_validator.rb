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

# require 'resolv'
require 'ipaddress'
require 'addressable/uri'

module CamaleonCms
  class UserUrlValidator
    LOCAL_IPS = %w[0.0.0.0 ::].freeze

    def self.validate(...)
      new.validate(...)
    end

    def initialize
      @errors = []
    end

    # Validates the given url according to the constraints specified by the received arguments.
    #
    # allow_localhost - Registers error if URL resolves to a localhost IP address and argument is false.
    # allow_local_network - Registers error if URL resolves to a link-local address and argument is false.
    # enforce_user - Registers error if URL user doesn't start with alphanumeric characters and argument is true.
    # enforce_sanitizing - Registers error if URL includes any HTML/CSS/JS tags and argument is true.
    #
    # Returns an array with [<uri>, <original-hostname>].
    def validate(url, allow_localhost: false, allow_local_network: false, enforce_user: true, enforce_sanitizing: true)
      return invalid_url unless url.present?

      # Param url can be a string, URI or Addressable::URI
      return invalid_url unless (uri = parse_url(url))

      validate_uri(uri: uri, enforce_sanitizing: enforce_sanitizing, enforce_user: enforce_user)
      return @errors if @errors.any?

      address_info = get_address_info(uri)
      return @errors if @errors.any?

      validate_local_request(
        address_info: address_info,
        allow_localhost: allow_localhost,
        allow_local_network: allow_local_network
      )

      @errors.empty? || @errors
    end

    private

    def validate_uri(uri:, enforce_sanitizing:, enforce_user:)
      validate_html_tags(uri) if enforce_sanitizing

      validate_user(uri.user) if enforce_user
      validate_hostname(uri.hostname)
    end

    # @param uri [Addressable::URI]
    # @return [Array<Addrinfo>] addrinfo object for the URI
    def get_address_info(uri)
      Addrinfo.getaddrinfo(uri.hostname, get_port(uri), nil, :STREAM).map do |addr|
        addr.ipv6_v4mapped? ? addr.ipv6_to_ipv4 : addr
      end
    rescue ArgumentError => e
      # Addrinfo.getaddrinfo errors if the domain exceeds 1024 characters.
      @errors << I18n.t('camaleon_cms.admin.validate.hostname_long') if e.message.include?('hostname too long')

      @errors << "#{e.message}: #{I18n.t('camaleon_cms.admin.validate.url')}" if @errors.blank?
    rescue SocketError
      @errors << I18n.t('camaleon_cms.admin.validate.host_invalid')
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

    def validate_html_tags(uri)
      uri_str = uri.to_s
      sanitized_uri = ActionController::Base.helpers.sanitize(uri_str, tags: [])
      @errors << I18n.t('camaleon_cms.admin.validate.html_tags') unless sanitized_uri == uri_str
    end

    # @param [String, Addressable::URI, #to_str] url The URL string to parse
    # @return [Addressable::URI, nil] URI object based on the parsed string, or `nil` if the `url` is invalid
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

      return true if url =~ /[\n\r]/
      # Google Cloud Storage uses a multi-line, encoded Signature query string
      return false if %w[http https].include?(parsed_url.scheme&.downcase)

      CGI.unescape(url) =~ /[\n\r]/
    end

    def validate_user(value)
      return if value.blank?
      return if value =~ /\A\p{Alnum}/

      @errors << I18n.t('camaleon_cms.admin.validate.username_alphanumeric')
    end

    def validate_hostname(value)
      return if value.blank?
      return if IPAddress.valid?(value)
      return if value =~ /\A\p{Alnum}/

      @errors << I18n.t('camaleon_cms.admin.validate.host_or_ip_invalid')
    end

    def validate_localhost(addrs_info)
      return if (Socket.ip_address_list.map(&:ip_address).concat(LOCAL_IPS) & addrs_info.map(&:ip_address)).empty?

      @errors << I18n.t('camaleon_cms.admin.validate.no_localhost_requests')
    end

    def validate_loopback(addrs_info)
      return unless addrs_info.any? { |addr| addr.ipv4_loopback? || addr.ipv6_loopback? }

      @errors << I18n.t('camaleon_cms.admin.validate.no_loopback_requests')
    end

    def validate_local_network(addrs_info)
      return unless addrs_info.any? { |addr| addr.ipv4_private? || addr.ipv6_sitelocal? || addr.ipv6_unique_local? }

      @errors << I18n.t('camaleon_cms.admin.validate.no_local_net_requests')
    end

    def validate_link_local(addrs_info)
      netmask = IPAddr.new('169.254.0.0/16')
      return unless addrs_info.any? { |addr| addr.ipv6_linklocal? || netmask.include?(addr.ip_address) }

      @errors << I18n.t('camaleon_cms.admin.validate.no_link_local_net_requests')
    end

    def validate_shared_address(addrs_info)
      netmask = IPAddr.new('100.64.0.0/10')
      return unless addrs_info.any? { |addr| netmask.include?(addr.ip_address) }

      @errors << I18n.t('camaleon_cms.admin.validate.no_shared_address_requests')
    end

    # Registers an error if any IP in `addrs_info` is the limited broadcast address.
    # https://datatracker.ietf.org/doc/html/rfc919#section-7
    def validate_limited_broadcast_address(addrs_info)
      blocked_ips = ['255.255.255.255']

      return if (blocked_ips & addrs_info.map(&:ip_address)).empty?

      @errors << I18n.t('camaleon_cms.admin.validate.no_limited_broadcast_address_requests')
    end

    def invalid_url
      @errors << I18n.t('camaleon_cms.admin.validate.url')
    end
  end
end
