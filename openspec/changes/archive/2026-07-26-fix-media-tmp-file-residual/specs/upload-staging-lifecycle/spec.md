## ADDED Requirements

### Requirement: Oversized payloads are rejected before being decoded or written

The system SHALL reject a `data:` upload that exceeds the permitted size before decoding it, estimating the decoded size from the length of the base64 source, so that oversized content is never allocated in full nor written to the staging directory.

#### Scenario: Oversized data: payload is rejected before decoding
- **WHEN** a `crop_url` upload supplies a `data:` URI whose base64 length implies a decoded size above the site's `filesystem_max_size`
- **THEN** the system returns the file-size error
- **AND** no file is created under `public/tmp/{site_id}/`

#### Scenario: Payload within the limit is accepted
- **WHEN** a `crop_url` upload supplies a `data:` URI whose implied decoded size is below `filesystem_max_size`
- **THEN** the upload proceeds normally

### Requirement: The staging size limit defaults to the site setting

The system SHALL default the upload size limit in `cama_tmp_upload` to the site's `filesystem_max_size` option when the caller does not supply one, so the limit applies on the media controller paths rather than being skipped.

#### Scenario: crop_url is bounded without passing an explicit maximum
- **WHEN** `cama_tmp_upload` is invoked from `crop_url` with no `:maximum` argument
- **THEN** the site's `filesystem_max_size` is applied as the limit

#### Scenario: Explicit maximum still wins
- **WHEN** a caller passes an explicit `:maximum` to `cama_tmp_upload`
- **THEN** that value is used instead of the site option

### Requirement: Failed uploads leave no staged file behind

The system SHALL remove any file it wrote into the upload staging directory when the upload that produced it returns an error, regardless of which validation rejected it.

#### Scenario: Format rejection removes the staged file
- **WHEN** an upload is rejected because its extension is outside the requested `formats`
- **THEN** the response reports the file-format error
- **AND** no file exists under `public/tmp/{site_id}/` for that upload

#### Scenario: Post-staging size rejection removes the staged file
- **WHEN** an upload reaches `upload_file` and is rejected there for exceeding the site's `filesystem_max_size`
- **THEN** the response reports the file-size error
- **AND** no file exists under `public/tmp/{site_id}/` for that upload

#### Scenario: Invalid folder rejection removes the staged file
- **WHEN** an upload is rejected because the requested destination folder fails `valid_folder_path?`
- **THEN** the response reports the invalid-path error
- **AND** no file exists under `public/tmp/{site_id}/` for that upload

### Requirement: Successful uploads retain the staged file for the caller

The system SHALL NOT remove the staged file when the upload succeeds, because the staging path is the return value of `cama_tmp_upload` and is consumed by the caller.

#### Scenario: Staged path is readable after a successful cama_tmp_upload
- **WHEN** `cama_tmp_upload` returns a result with a blank `:error`
- **THEN** the file at the returned `:file_path` exists and its full content can be read

#### Scenario: End-to-end upload still reaches the media library
- **WHEN** a media-permission user posts a `crop_url` upload of a valid PNG `data:` URI
- **THEN** the file is added to the media library under `public/media/{site_id}/`

### Requirement: Staging cleanup cannot delete outside the staging root

The system SHALL delete a staged file only after confirming the resolved path lies inside the staging directory, so that a malformed or hostile path can never cause deletion elsewhere on the filesystem.

#### Scenario: Path outside the staging root is not deleted
- **WHEN** staging cleanup is invoked with a path that canonicalizes outside `public/tmp/{site_id}/`
- **THEN** no file is deleted

### Requirement: Cleanup only removes sources the uploader owns

The system SHALL remove the source file in `upload_file` error paths only when the caller set `remove_source`, so that a caller-owned file passed in for upload is never deleted on failure.

#### Scenario: Caller-owned source survives a failed upload
- **WHEN** `upload_file` is called without `remove_source` and returns an error
- **THEN** the source file passed by the caller still exists

#### Scenario: Uploader-owned staged source is removed on failure
- **WHEN** `upload_file` is called with `remove_source` set and returns an error
- **THEN** the staged source file is removed

### Requirement: Cleanup applies to both uploader implementations

The system SHALL apply identical staging-cleanup behavior in `CamaleonCms::RuntimeUploaderConcern` and `CamaleonCms::UploaderHelper`, via shared code rather than duplicated logic.

#### Scenario: Helper copy cleans up on rejection
- **WHEN** an upload is rejected through the `UploaderHelper` implementation of `cama_tmp_upload`
- **THEN** no file exists under `public/tmp/{site_id}/` for that upload
