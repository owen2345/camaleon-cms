## Purpose

Define the requirements for detecting path traversal attempts in user-supplied URLs during URL validation. The system SHOULD check URL paths for `../` traversal segments to prevent SSRF validators from being bypassed by path traversal in the URL path component.

## Requirements

### Requirement: Path traversal in URL path is detected when enabled

The system SHALL detect `../` path traversal in URI paths when the `reject_path_traversal: true` option is passed to the URL validator. Detection SHALL decode percent-encoding via `Addressable::URI.unencode` then split on path separators and check for `..` segments, which handles URL-encoded traversal (`%2e%2e`) without falsely flagging harmless encodings like `%7E`.

#### Scenario: URL with ../ in path is rejected with path traversal detection

- **WHEN** a URL validator receives `http://example.com/../etc/passwd` with `reject_path_traversal: true`
- **THEN** the decoded path segments include `..`, and the validator returns an error

#### Scenario: URL with %2e%2e in path is rejected with path traversal detection

- **WHEN** a URL validator receives `http://example.com/%2e%2e/etc/passwd` with `reject_path_traversal: true`
- **THEN** `Addressable::URI.unencode` decodes `%2e%2e` to `..`, the split segments include `..`, and the validator returns an error

#### Scenario: Normal URL without traversal passes validation

- **WHEN** a URL validator receives `http://example.com/images/photo.jpg` with `reject_path_traversal: true`
- **THEN** no decoded segment equals `..`, and validation passes

### Requirement: Path traversal detection is opt-in

The system SHALL NOT enable path traversal detection by default in the URL validator. It MUST be explicitly enabled by the caller via the `reject_path_traversal` option.

#### Scenario: URL with ../ passes when traversal detection is off (default)

- **WHEN** a URL validator receives `http://example.com/../etc/passwd` without `reject_path_traversal: true`
- **THEN** the validator does NOT check for path traversal and passes the URL (other checks still apply)

### Requirement: Path traversal validation is disabled for data: URIs

The system SHALL skip URL validation for `data:` URIs in the crop URL controller action, since data URIs have no network component.

#### Scenario: data: URI in crop_url is accepted without validation

- **WHEN** a user submits `data:image/png;base64,iVBOR...` to the `crop_url` action
- **THEN** the system skips URL validation and processes the data URI directly
