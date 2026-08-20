## ADDED Requirements

### Requirement: A non-positive size limit means unlimited

`cama_size_limit_error` SHALL treat a non-positive `maximum` (zero or negative) as "no limit"
and accept any size, rather than rejecting every non-empty file. This is the single point every
caller's size check flows through — core's `upload_file`/`cama_tmp_upload`/data-URI staging and
plugin callers such as `cama_contact_form` that read `filesystem_max_size` and pass it as
`maximum:` — so a site whose stored `filesystem_max_size` is blank or `0` can still upload and
crop. A positive limit continues to reject sizes above it.

#### Scenario: Zero limit accepts an upload

- **WHEN** the size check runs with a `maximum` of `0` for a non-empty file
- **THEN** no size error is returned

#### Scenario: A crop succeeds on a site whose max file size is zero

- **WHEN** a site's `filesystem_max_size` option is `0` and a user crops an existing image
- **THEN** the crop is not rejected with a "File size exceeded (0 Bytes)" error

#### Scenario: A positive limit still rejects an oversized file

- **WHEN** the size check runs with a positive `maximum` and a file larger than it
- **THEN** a size error is returned
