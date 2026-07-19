# frozen_string_literal: true

require 'uri'

module CamaleonCms
  # Shared helpers that keep file-upload path handling in a single place so the
  # canonicalization guard and same-site URL detection cannot drift between
  # RuntimeUploaderConcern and UploaderHelper (which both include this module).
  module UploaderPathSecurity
    # Canonicalizes a string path and verifies it stays within the allowed upload
    # roots (the Rails public dir or the system tmp dir). Returns the expanded path
    # when valid, or nil when the path escapes the roots or is otherwise hostile
    # (null bytes, nil).
    def cama_canonical_upload_path(path)
      expanded = File.expand_path(path)
      roots = [Rails.public_path.to_s, Dir.tmpdir]
      return expanded if roots.any? { |r| expanded == r || expanded.start_with?(r + File::SEPARATOR) }

      nil
    rescue ArgumentError, TypeError
      nil
    end

    def same_site_url?(url, site)
      uri = URI.parse(url)
      site_uri = URI.parse(site.the_url(locale: nil))
      uri.host == site_uri.host && uri.port == site_uri.port
    rescue URI::InvalidURIError
      false
    end

    def site_url_path(url, site)
      uri = URI.parse(url)
      path = uri.path
      langs = site.get_languages
      path = path.sub(%r{\A/(?:#{Regexp.union(langs.map(&:to_s))})(?=/|$)}, '') if langs.size > 1
      path
    rescue URI::InvalidURIError
      url
    end
  end
end
