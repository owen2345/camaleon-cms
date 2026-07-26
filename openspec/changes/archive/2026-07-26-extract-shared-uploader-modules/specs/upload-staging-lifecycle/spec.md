## ADDED Requirements

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
