module CamaleonCms
  # Uploader entry point for controllers (mixed into CamaleonCms::CamaleonController and
  # re-exported through RuntimeStateConcern). The implementation lives in the shared
  # modules below, which CamaleonCms::UploaderHelper includes as well, so the two entry
  # points cannot drift. Only cama_upload_url_error is controller-specific.
  module RuntimeUploaderConcern
    extend ActiveSupport::Concern

    include UploaderContentSecurity
    include UploaderPathSecurity
    include UploaderPipeline
    include UploaderImageProcessing
    include UploaderSupport

    private

    # Validates a user-supplied upload URL and returns nil when it is acceptable,
    # or an error String to render. Only http(s) URLs are validated here; other
    # inputs (local paths, data: URIs) are handled by the sink guards in
    # cama_tmp_upload/upload_file.
    #
    # Same-site URLs are mapped to a local file and read directly (no network
    # request), so they only need the static path-traversal check — not DNS
    # resolution, SSRF/private-IP blocking, or HTML-tag sanitizing. Applying those
    # to a same-site URL wrongly rejects legitimate values: hosts that resolve to a
    # loopback/private IP (localhost, Docker, intranet), non-resolvable dev hosts,
    # and multi-parameter query strings (the "&" is escaped by sanitize). Remote
    # URLs, which are actually fetched, still get the full SSRF validation.
    def cama_upload_url_error(url)
      return unless url.to_s.start_with?('http://', 'https://')

      result = if same_site_url?(url, current_site)
                 UserUrlValidator.validate(url, reject_path_traversal: true, resolve: false,
                                                enforce_sanitizing: false, enforce_user: false,
                                                allow_localhost: true, allow_local_network: true)
               else
                 UserUrlValidator.validate(url, reject_path_traversal: true)
               end
      result.join(', ') if result.is_a?(Array)
    end
  end
end
