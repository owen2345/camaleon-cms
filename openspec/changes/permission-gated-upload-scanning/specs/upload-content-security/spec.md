## MODIFIED Requirements

### Requirement: Content is scanned before being written to a web-served path

The system SHALL scan upload content for malicious patterns before writing it into the upload staging directory, so that rejected content is never present — even transiently — at a path served by the web server.

Whether the scan runs is decided by authorization, not by the location of the source file. An upload SHALL be scanned unless the uploading user holds the `media_unfiltered_upload` permission. For a user without it every upload is scanned, whatever the source — a `data:` payload, a remote download, a private-media file, or a file already published under `Rails.public_path`. The previous exemption for sources already under the public root is withdrawn: it was keyed on the source path while the scan ruleset and the served `Content-Type` are keyed on the caller-supplied output filename, so a source accepted under one extension could be rewritten to another and served as live markup without being re-scanned.

Scanning rejects; it never repairs. Content that trips a rule SHALL be refused with `Potentially malicious content found!` rather than sanitized, escaped or rewritten.

#### Scenario: data: payload is scanned before staging
- **WHEN** a `crop_url` upload supplies a `data:` URI whose decoded payload contains a `<script>` tag
- **THEN** the payload is rejected without any file being created under `public/tmp/{site_id}/`

#### Scenario: Downloaded remote body is scanned before staging
- **WHEN** a remote URL upload returns a body containing an event-handler attribute
- **THEN** the body is rejected without being written into `public/tmp/{site_id}/`

#### Scenario: Hostile payload is never retrievable from the staging path
- **WHEN** a media-permission user posts a `crop_url` upload named `x.html` whose `data:` payload contains `<script>`
- **THEN** no file is ever created at `public/tmp/{site_id}/x.html`, so a concurrent request for `/tmp/{site_id}/x.html` cannot retrieve the payload at any point

#### Scenario: An already-published file is re-scanned when re-cropped
- **WHEN** a user without `media_unfiltered_upload` uses a file already stored under `Rails.public_path` as the source of a crop
- **THEN** the content scan runs against the source, using the output filename to select the ruleset

#### Scenario: Re-crop under a different extension cannot bypass the ruleset
- **WHEN** a user without `media_unfiltered_upload` uploads an SVG that the SVG ruleset accepts, then re-crops it supplying an output name ending in `.html`
- **THEN** the re-crop is scanned under the non-SVG ruleset and rejected, so the bytes are never served as `text/html`

#### Scenario: A private-media source is still scanned
- **WHEN** a file outside the public root (for example under the private-media directory) is used as an upload source
- **THEN** the content scan runs as before

#### Scenario: A permitted user uploads without scanning
- **WHEN** a user holding `media_unfiltered_upload` uploads a file whose content matches a blocked pattern
- **THEN** the upload is accepted, because the permission exempts the uploader from scanning

#### Scenario: Scanning is skipped without reading the file for a permitted user
- **WHEN** the permission check answers true
- **THEN** the content scan is not performed, so the file is not read in order to scan it
