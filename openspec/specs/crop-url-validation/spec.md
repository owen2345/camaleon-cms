## Purpose

Define the requirements for validating user-supplied URLs in the crop controller action before passing them to the temporary upload pipeline. The crop action SHALL validate HTTP/HTTPS URLs before delegating to `cama_tmp_upload`, applying validation appropriate to how the URL is consumed: same-site URLs are read from the local filesystem, while remote URLs are fetched over the network. This provides consistent defense-in-depth across the media controller entry points (`crop`, `crop_url`, `upload`) via the shared `cama_upload_url_error` helper.

## Requirements

### Requirement: Crop action validates HTTP/HTTPS URLs before processing

The crop controller action SHALL validate user-supplied URLs via `cama_upload_url_error` when `cp_img_path` is an HTTP or HTTPS URL, before delegating to `cama_tmp_upload`. Same-site URLs (mapped to a local file, read without any network request) SHALL be validated for path traversal only, without DNS resolution, SSRF/private-IP blocking, or HTML-tag sanitizing. Remote URLs (actually fetched) SHALL receive the full `UserUrlValidator` SSRF validation. Non-URL paths and data URIs SHALL pass through without controller-level URL validation (existing guards in `cama_tmp_upload` apply).

#### Scenario: Valid same-origin image URL passes through
- **WHEN** the crop action receives `cp_img_path` set to a valid HTTP URL pointing at an image on the same site — including a host that resolves to a loopback/private IP (localhost, intranet) or a multi-parameter query string
- **THEN** the URL SHALL pass validation and proceed to `cama_tmp_upload` without a DNS lookup

#### Scenario: URL with path traversal is rejected
- **WHEN** the crop action receives `cp_img_path` set to an HTTP URL containing `..` path segments (including percent-encoded and multiply-encoded forms, e.g., `http://site.example/../config/secrets.yml`)
- **THEN** the action SHALL return an error response and SHALL NOT call `cama_tmp_upload`

#### Scenario: Remote URL resolving to an internal address is rejected
- **WHEN** the crop action receives `cp_img_path` set to a remote HTTP URL whose host resolves to a loopback/private/link-local address
- **THEN** the action SHALL return an SSRF error response and SHALL NOT call `cama_tmp_upload`

#### Scenario: Non-URL path passes through without controller-level validation
- **WHEN** the crop action receives `cp_img_path` set to a local file system path (e.g., `/etc/passwd`)
- **THEN** the action SHALL pass the path directly to `cama_tmp_upload` without URL validation (existing `cama_tmp_upload` guards handle it). Unlike `crop_url`, a bare relative path is treated as a filesystem path and is NOT prefixed with the site URL — an intentional divergence, since `crop` supports filesystem-path inputs.

#### Scenario: data: URI passes through without controller-level validation
- **WHEN** the crop action receives `cp_img_path` set to a data URI
- **THEN** the action SHALL pass the URI (with `name`/`formats`) directly to `cama_tmp_upload` without URL validation (existing `cama_tmp_upload` guards handle it)
