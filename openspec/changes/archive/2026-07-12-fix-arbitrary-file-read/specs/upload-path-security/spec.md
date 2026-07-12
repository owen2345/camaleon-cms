## Purpose

Define the security requirements for validating file upload source paths. The system MUST NOT accept string paths that reference files outside of controlled temporary directories, preventing arbitrary server-side file reads.

## Requirements

### Requirement: Reject uploads with server file paths in file_upload

The system SHALL reject file uploads where the `file_upload` parameter is a plain string path referencing a file outside the system's public or temp directories.

#### Scenario: Absolute path to system file is rejected
- **WHEN** a user sends `POST /admin/media/upload` with `file_upload=/etc/hostname` and no `file_upload` file attachment
- **THEN** the system returns an error and does NOT read or serve the file

#### Scenario: Path traversal in file_upload is rejected
- **WHEN** a user sends `POST /admin/media/upload` with `file_upload=../../../etc/passwd`
- **THEN** the system returns an error and does NOT read the file

#### Scenario: Regular file upload still works
- **WHEN** a user uploads a file via multipart form (ActionDispatch::Http::UploadedFile)
- **THEN** the system accepts and processes the upload normally

### Requirement: Reject path traversal in crop cp_img_path

The system SHALL reject the crop action when `cp_img_path` references files outside the system's temp or media directories.

#### Scenario: Path traversal in cp_img_path is rejected
- **WHEN** a user sends `GET /admin/media/crop` with `cp_img_path=/etc/passwd`
- **THEN** the system returns an error and does NOT open the file

### Requirement: String paths must resolve to allowed directories

The system SHALL only call `File.open` on string paths that start with `Rails.public_path` or `Dir.tmpdir`.

#### Scenario: Temp file path from cama_download_remote_file is accepted
- **WHEN** a URL upload downloads a remote file to a Tempfile in `Dir.tmpdir`
- **THEN** the Tempfile path is accepted for `File.open`

#### Scenario: Temp file path from cama_tmp_upload is accepted
- **WHEN** a data URI is saved to a temp file under `Rails.public_path/tmp/`
- **THEN** the temp file path is accepted for `File.open`

### Requirement: Format validation must not be bypassed by omitting formats

The system SHALL enforce format validation even when the `formats` parameter is omitted from the upload request.

#### Scenario: Upload without formats param enforces default format check
- **WHEN** a user uploads a file without specifying `formats`
- **THEN** the system applies the default format validation (`*`) rather than bypassing validation
