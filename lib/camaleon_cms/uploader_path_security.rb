# frozen_string_literal: true

require 'addressable/uri'

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

    # True when the canonicalized path stays strictly inside the given root
    # directory. Used as a defense-in-depth check around write sinks.
    def path_within?(path, root)
      File.expand_path(path).start_with?("#{File.expand_path(root)}#{File::SEPARATOR}")
    rescue ArgumentError, TypeError
      false
    end

    def same_site_url?(url, site)
      uri = Addressable::URI.parse(url)
      site_uri = Addressable::URI.parse(site.the_url(locale: nil))
      uri.host&.downcase == site_uri.host&.downcase && uri.inferred_port == site_uri.inferred_port
    rescue Addressable::URI::InvalidURIError
      false
    end

    def site_url_path(url, site)
      uri = Addressable::URI.parse(url)
      path = uri.path.to_s
      langs = site.get_languages
      path = path.sub(%r{\A/(?:#{Regexp.union(langs.map(&:to_s))})(?=/|$)}, '') if langs.size > 1
      path
    rescue Addressable::URI::InvalidURIError
      url
    end
  end
end
