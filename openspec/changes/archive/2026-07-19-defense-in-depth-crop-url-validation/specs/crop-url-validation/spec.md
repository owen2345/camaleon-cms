## ADDED Requirements

### Requirement: Crop action validates HTTP/HTTPS URLs before processing

The crop controller action SHALL validate user-supplied HTTP/HTTPS URLs via the `cama_upload_url_error` shared helper before delegating to `cama_tmp_upload`. The helper SHALL call `UserUrlValidator.validate` with `reject_path_traversal: true`, using lighter parameters for same-site URLs (no DNS/SSRF resolution) and full validation for remote URLs. Non-URL paths and data URIs SHALL pass through without additional validation in the crop action (existing guards in `cama_tmp_upload` apply). The `formats` and `name` parameters SHALL be forwarded to `cama_tmp_upload`.

#### Scenario: Valid same-origin image URL passes through
- **WHEN** the crop action receives `cp_img_path` set to a valid HTTP URL pointing at an image on the same site
- **THEN** the URL SHALL pass validation and proceed to `cama_tmp_upload`

#### Scenario: URL with path traversal is rejected
- **WHEN** the crop action receives `cp_img_path` set to an HTTP URL containing `..` path segments (e.g., `http://site.example/../config/secrets.yml`)
- **THEN** the action SHALL return an error response and SHALL NOT call `cama_tmp_upload`

#### Scenario: Non-URL path passes through without controller-level validation
- **WHEN** the crop action receives `cp_img_path` set to a local file system path (e.g., `/etc/passwd`)
- **THEN** the action SHALL pass the path directly to `cama_tmp_upload` without URL validation (existing `cama_tmp_upload` guards handle it)

#### Scenario: data: URI passes through without controller-level validation
- **WHEN** the crop action receives `cp_img_path` set to a data URI
- **THEN** the action SHALL pass the URI directly to `cama_tmp_upload` without URL validation (existing `cama_tmp_upload` guards handle it)

#### Scenario: Remote URL with link-local address is rejected before any network request
- **WHEN** the crop action receives `cp_img_path` set to an HTTP URL that is not same-site (e.g., `http://169.254.169.254/`)
- **THEN** the helper SHALL perform full SSRF validation and reject the URL with an error about restricted network addresses

#### Scenario: name and formats parameters are forwarded to cama_tmp_upload
- **WHEN** the crop action receives `cp_img_path` set to a data URI together with `name` and `formats` parameters
- **THEN** the action SHALL pass all three parameters to `cama_tmp_upload`
