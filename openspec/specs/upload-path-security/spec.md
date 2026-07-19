## Purpose

Define the security requirements for validating file upload source paths. The system MUST canonicalize string paths before validating them against allowed directory prefixes, preventing path traversal bypasses where `../` segments after an allowed prefix resolve to arbitrary filesystem locations.

## Requirements

### Requirement: Paths are canonicalized before prefix validation

The system SHALL canonicalize string paths using `File.expand_path` before comparing them against allowed directory prefixes. The canonicalized path MUST equal the allowed root or start with the root followed by the path separator.

#### Scenario: Path with .. after allowed prefix is rejected

- **WHEN** a user sends `POST /admin/media/upload` with `file_upload=/app/public/../../../etc/passwd`
- **THEN** `File.expand_path` resolves it to `/etc/passwd`, the prefix check fails, and the system returns an error

#### Scenario: Absolute path to system file is rejected

- **WHEN** a user sends `POST /admin/media/upload` with `file_upload=/etc/hostname`
- **THEN** the system returns an error and does NOT read or serve the file

#### Scenario: Path traversal in file_upload is rejected

- **WHEN** a user sends `POST /admin/media/upload` with `file_upload=../../../etc/passwd`
- **THEN** the system returns an error and does NOT read the file

#### Scenario: Regular file upload still works

- **WHEN** a user uploads a file via multipart form (ActionDispatch::Http::UploadedFile)
- **THEN** the system accepts and processes the upload normally

#### Scenario: Temp file path under public is accepted

- **WHEN** a temp file under `Rails.public_path/tmp/` is passed as a string
- **THEN** `File.expand_path` returns the canonical path, the prefix check passes, and the file is accepted

### Requirement: Path traversal in crop cp_img_path is rejected

The system SHALL reject the crop action when `cp_img_path` references files outside the system's temp or media directories, using canonicalized path comparison.

#### Scenario: Path traversal in cp_img_path is rejected

- **WHEN** a user sends `GET /admin/media/crop` with `cp_img_path=/etc/passwd`
- **THEN** the system returns an error and does NOT open the file

#### Scenario: Traversal with allowed prefix in cp_img_path is rejected

- **WHEN** a user sends `GET /admin/media/crop` with `cp_img_path=/app/public/../../../etc/passwd`
- **THEN** `File.expand_path` resolves it outside allowed roots, and the system rejects it

### Requirement: Null bytes and nil input are safely rejected

The system SHALL rescue `ArgumentError` (null bytes) and `TypeError` (nil) from `File.expand_path` and reject the input.

#### Scenario: Path with null byte is rejected

- **WHEN** a user sends a path containing a null byte (`\0`)
- **THEN** `File.expand_path` raises `ArgumentError`, the rescue block returns an error

#### Scenario: nil path is rejected

- **WHEN** a user sends `nil` as the file path
- **THEN** `File.expand_path` raises `TypeError`, the rescue block returns an error

### Requirement: URL-to-path conversion uses host comparison

When converting a URL to a local filesystem path, the system SHALL compare host and port (not substring match) before substituting the site URL with the public path.

#### Scenario: Same-host URL is converted to local path

- **WHEN** a user provides a URL matching the current site's host and port
- **THEN** the system converts the URL path to a local filesystem path under `Rails.public_path`

#### Scenario: Different-host URL is not converted

- **WHEN** a user provides a URL with a different host than the current site
- **THEN** the system does NOT convert the URL to a local path (it's treated as a remote URL or rejected)

#### Scenario: Substring-matched host in query is not converted

- **WHEN** a user provides `http://evil.com?url=http://site.com/path`
- **THEN** the substring match does NOT trigger URL-to-path conversion (host comparison fails)
