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
    #
    # `extra_roots` widens the set for this call only, so trusted application code
    # (plugins, jobs, imports) can stage files elsewhere. It MUST come from
    # application code or operator configuration — never from a request parameter,
    # since Admin::MediaController#crop feeds params[:cp_img_path] into this check and
    # the default roots are what stop it reading arbitrary files.
    def cama_canonical_upload_path(path, extra_roots: [])
      expanded = File.expand_path(path)
      roots = cama_allowed_upload_roots(extra_roots)
      return expanded if roots.any? { |r| expanded == r || expanded.start_with?(r + File::SEPARATOR) }

      nil
    rescue ArgumentError, TypeError
      nil
    end

    # The default roots plus any caller-supplied ones, and the private-media directory
    # while the uploader is in private mode (so private files can be cropped without
    # widening the roots for anything else).
    def cama_allowed_upload_roots(extra_roots = [])
      roots = [Rails.public_path.to_s, Dir.tmpdir]
      roots << cama_private_upload_root if cama_private_upload_mode?
      roots.concat(Array.wrap(extra_roots).compact_blank.map { |r| File.expand_path(r.to_s) })
      roots.compact_blank
    end

    def cama_private_upload_root
      Rails.root.join(CamaleonCmsUploader::PRIVATE_DIRECTORY).to_s
    end

    def cama_private_upload_mode?
      respond_to?(:cama_uploader, true) && cama_uploader.try(:is_private_uploader?).present?
    rescue StandardError
      false
    end

    # Reads a caller-supplied root list off an options hash, accepting either key
    # form. Only application code populates this; see cama_canonical_upload_path.
    def cama_extra_upload_roots(options)
      opts = options.try(:to_h) || {}
      Array.wrap(opts[:allowed_roots] || opts['allowed_roots'])
    end

    # Removes a staged upload file, but only after confirming it canonicalizes
    # inside the given staging root. A bug in the calling code therefore cannot
    # turn into a deletion elsewhere on the filesystem. Returns true when a file
    # was removed.
    def cama_purge_staged_file(path, root)
      return false if path.blank? || root.blank?
      return false unless path_within?(path, root)

      FileUtils.rm_f(path)
      true
    rescue ArgumentError, TypeError
      false
    end

    # Upper bound on the decoded byte size of a base64 payload, computed without
    # decoding it, so an oversized upload can be rejected before it is allocated.
    # Overestimates by at most two bytes (padding), erring toward rejecting early.
    def cama_base64_decoded_size(payload)
      payload.to_s.bytesize * 3 / 4
    end

    # Passes an upload error through untouched, first removing the staging file when
    # this upload owns it (remove_source), so a rejected upload leaves nothing behind
    # in the web-served public/tmp directory. Shared so the cleanup rule cannot drift
    # between RuntimeUploaderConcern and UploaderHelper.
    def cama_upload_failure(error, uploaded_io, settings)
      # The first (malicious-content) rejection in upload_file runs before settings are
      # deep-symbolized, so honor a string-keyed remove_source too — otherwise a rejected upload
      # owning its staging file leaks it in the web-served public/tmp directory.
      remove_source = settings[:remove_source] || settings['remove_source']
      return error unless remove_source

      cama_purge_staged_file(uploaded_io.try(:path), File.join(Rails.public_path, 'tmp').to_s)
      error
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
