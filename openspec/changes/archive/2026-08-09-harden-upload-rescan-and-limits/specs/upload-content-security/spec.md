## ADDED Requirements

### Requirement: Content substituted by a before_upload handler is re-scanned

The `before_upload` hook runs after the initial content scan and may replace the IO the pipeline
persists (`settings[:uploaded_io]`). When the uploading user does not hold
`media_unfiltered_upload`, the pipeline SHALL detect a replacement by object identity across the
hook and re-scan the substituted content before writing it; content that trips a rule SHALL be
refused with `Potentially malicious content found!` and no file SHALL be written. A user holding
the permission is exempt from this re-scan exactly as from the initial scan. When no handler
replaces the IO, no second scan is performed (the initial scan already covered those bytes).

This closes the gap where a handler (for example an image optimizer rewriting an SVG) could
substitute bytes the scanner never saw. It implements the `security-capability-gating`
"content substituted after the check" requirement for the upload path.

#### Scenario: Handler-substituted bytes are re-scanned for an untrusted uploader

- **WHEN** a user without `media_unfiltered_upload` uploads a clean file and a `before_upload`
  handler replaces `settings[:uploaded_io]` with content containing a `<script>` tag
- **THEN** the substituted content is re-scanned and the upload is refused, with no file written

#### Scenario: A permitted user's handler substitution is not re-scanned

- **WHEN** a user holding `media_unfiltered_upload` uploads a file and a `before_upload` handler
  replaces the IO
- **THEN** the substituted content is persisted without a re-scan, as the permission exempts it

#### Scenario: An unchanged IO is not re-scanned

- **WHEN** a user without `media_unfiltered_upload` uploads a file and no `before_upload` handler
  replaces `settings[:uploaded_io]`
- **THEN** the pipeline does not scan the content a second time after the hook
