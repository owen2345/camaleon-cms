## Purpose

Define the lifecycle requirements for files staged in the upload staging directory (`public/tmp/{site_id}/`). Uploads MUST be bounded before their content is decoded or written, and any file the uploader stages MUST be removed when the upload fails, so that rejected or oversized payloads are never left behind at a web-served path.
## Requirements
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

### Requirement: The staged filename is taken from the caller's arguments

The system SHALL determine whether a `data:` upload supplies a filename from the `:name` argument passed to `cama_tmp_upload`, not from request parameters, so that staging is decided by the caller's own arguments and remains callable outside a controller.

#### Scenario: A data: upload without a name is rejected
- **WHEN** `cama_tmp_upload` is called with a `data:` URI and no `:name` argument
- **THEN** the name-required error is returned
- **AND** no file is created under `public/tmp/{site_id}/`

#### Scenario: A data: upload with a name is staged
- **WHEN** `cama_tmp_upload` is called with a `data:` URI and a `:name` argument
- **THEN** the payload is staged under `public/tmp/{site_id}/` using that name

#### Scenario: The media controller path is unaffected
- **WHEN** a `crop_url` request supplies a `data:` URI and a blank `name` parameter
- **THEN** the name-required error is returned, as before, because the controller passes `name: params[:name]` through to `cama_tmp_upload`

### Requirement: A non-positive size limit means unlimited

`cama_size_limit_error` SHALL treat a non-positive `maximum` (zero or negative) as "no limit"
and accept any size, rather than rejecting every non-empty file. This is the single point every
caller's size check flows through — core's `upload_file`/`cama_tmp_upload`/data-URI staging and
plugin callers such as `cama_contact_form` that read `filesystem_max_size` and pass it as
`maximum:` — so a site whose stored `filesystem_max_size` is blank or `0` can still upload and
crop. A positive limit continues to reject sizes above it. The size comparison SHALL coerce
`maximum`, so a positive numeric-string limit is enforced rather than raising a comparison
error.

#### Scenario: Zero limit accepts an upload

- **WHEN** the size check runs with a `maximum` of `0` for a non-empty file
- **THEN** no size error is returned

#### Scenario: A crop succeeds on a site whose max file size is zero

- **WHEN** a site's `filesystem_max_size` option is `0` and a user crops an existing image
- **THEN** the crop is not rejected with a "File size exceeded (0 Bytes)" error

#### Scenario: A positive limit still rejects an oversized file

- **WHEN** the size check runs with a positive `maximum` and a file larger than it
- **THEN** a size error is returned

#### Scenario: A numeric-string limit is enforced

- **WHEN** the size check runs with a positive numeric-string `maximum` and a file larger than
  that value
- **THEN** a size error is returned

