## ADDED Requirements

### Requirement: Cleanup honors a string-keyed remove_source on the pre-symbolize failure path

The staged-file cleanup seam (`cama_upload_failure`) SHALL purge an uploader-owned staged file when
`remove_source` is set under either a symbol or a string key. The first (malicious-content)
rejection in `upload_file` runs before settings are deep-symbolized, so a caller passing a
string-keyed `remove_source` MUST NOT leave its staged file behind in the web-served staging root.

#### Scenario: A rejected upload with a string-keyed remove_source is purged

- **WHEN** an untrusted upload of malicious content is submitted with `{ 'remove_source' => true }`
  (a string key), triggering the pre-symbolize content rejection
- **THEN** the upload is rejected with an error
- **AND** the uploader-owned staged file is removed from the staging root
