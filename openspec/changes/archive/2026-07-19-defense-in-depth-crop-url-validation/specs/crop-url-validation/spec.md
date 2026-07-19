## ADDED Requirements

### Requirement: Crop action validates HTTP/HTTPS URLs before processing

The crop controller action SHALL validate user-supplied URLs via `UserUrlValidator.validate` with `reject_path_traversal: true` when `cp_img_path` is an HTTP or HTTPS URL, before delegating to `cama_tmp_upload`. Non-URL paths and data URIs SHALL pass through without additional validation in the crop action (existing guards in `cama_tmp_upload` apply).

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
