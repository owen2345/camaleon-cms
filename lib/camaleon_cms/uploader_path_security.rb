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
      same_host?(uri.host, site_uri.host) && uri.inferred_port == site_uri.inferred_port
    rescue Addressable::URI::InvalidURIError
      false
    end

    # Case-insensitive host comparison that also ignores a single trailing dot, so
    # a fully-qualified form ("site.com.") still matches the site host ("site.com")
    # instead of being classified as a remote host — which would trigger a needless
    # (and re-validated) outbound fetch to the site itself.
    def same_host?(host_a, host_b)
      return false if host_a.blank? || host_b.blank?

      host_a.downcase.chomp('.') == host_b.downcase.chomp('.')
    end

    def site_url_path(url, site)
      uri = Addressable::URI.parse(url)
      path = uri.path.to_s
      # Strip the site's mount subpath (relative_url_root), if any, so that a
      # same-site URL under e.g. "http://host/blog/" maps to public/... and not
      # public/blog/...
      base = Addressable::URI.parse(site.the_url(locale: nil)).path.to_s.chomp('/')
      path = path.sub(%r{\A#{Regexp.escape(base)}(?=/|$)}, '') if base.present?
      strip_locale_prefix(path, site)
    rescue Addressable::URI::InvalidURIError
      url
    end

    # Removes a leading locale segment (e.g. "/es") on multi-language sites. To
    # avoid mis-stripping a real first directory that merely shares a language
    # code's name, only strip when the stripped path points at an existing file
    # under the public dir; otherwise keep the path as-is.
    def strip_locale_prefix(path, site)
      langs = site.get_languages
      return path unless langs.size > 1

      stripped = path.sub(%r{\A/(?:#{Regexp.union(langs.map(&:to_s))})(?=/|$)}, '')
      return path if stripped == path

      File.exist?(File.expand_path(File.join(Rails.public_path, stripped))) ? stripped : path
    end
  end
end
