## Purpose

Define the security requirements for validating file upload source paths. The system MUST canonicalize string paths before validating them against allowed directory prefixes, preventing path traversal bypasses where `../` segments after an allowed prefix resolve to arbitrary filesystem locations.

## Requirements

### Requirement: Paths are canonicalized before prefix validation

The system SHALL canonicalize string paths using `File.expand_path` before comparing them against allowed directory prefixes. The canonicalized path MUST equal the allowed root or start with the root followed by the path separator.

The default allowed roots are the Rails public directory and the system temp directory. Trusted application code MAY extend the root set for a single call by passing additional roots (`allowed_roots:`), so plugins, background jobs and imports can stage files elsewhere. Additional roots SHALL originate only from application code or operator configuration: a value derived from request parameters MUST NOT be able to widen the root set, and the roots applied to a request-driven upload SHALL be the defaults. While the uploader is in private mode, the private-media directory SHALL also be an allowed root.

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

#### Scenario: A trusted caller stages a file outside the default roots

- **WHEN** application code calls `upload_file(path, allowed_roots: [Rails.root.join('storage').to_s])` with a path under `Rails.root/storage`
- **THEN** the prefix check passes and the file is accepted

#### Scenario: An extra root does not widen other calls

- **WHEN** one call passes `allowed_roots:` for a directory
- **AND** a later call for a path in that same directory passes no `allowed_roots:`
- **THEN** the later call is rejected, because the extension applies only to the call that requested it

#### Scenario: A request cannot widen the root set

- **WHEN** a request supplies parameters attempting to add an allowed root (e.g. an `allowed_roots` form field)
- **THEN** the upload is validated against the default roots only, and a path outside them is rejected

#### Scenario: Private media is readable while private mode is active

- **WHEN** the uploader is in private mode and a path under the private-media directory is used as an upload source
- **THEN** the prefix check passes
- **AND** the same path is rejected when private mode is not active

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
