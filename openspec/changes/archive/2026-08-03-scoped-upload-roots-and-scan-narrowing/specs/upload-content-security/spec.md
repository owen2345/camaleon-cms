## MODIFIED Requirements

### Requirement: Content is scanned before being written to a web-served path

The system SHALL scan upload content for malicious patterns before writing it into the upload staging directory, so that rejected content is never present — even transiently — at a path served by the web server.

Content whose source is an existing file under `Rails.public_path` is exempt from this scan: the bytes are already published at a URL the web server hands out, so re-scanning them when they are used as an upload source (a re-crop, or a same-site URL) removes no exposure that the original upload did not already create. The exemption is keyed on the canonicalized source path being inside the public root — sources outside it, including remote downloads, `data:` payloads, and private-media files, SHALL be scanned as before.

#### Scenario: data: payload is scanned before staging
- **WHEN** a `crop_url` upload supplies a `data:` URI whose decoded payload contains a `<script>` tag
- **THEN** the payload is rejected without any file being created under `public/tmp/{site_id}/`

#### Scenario: Downloaded remote body is scanned before staging
- **WHEN** a remote URL upload returns a body containing an event-handler attribute
- **THEN** the body is rejected without being written into `public/tmp/{site_id}/`

#### Scenario: Hostile payload is never retrievable from the staging path
- **WHEN** a media-permission user posts a `crop_url` upload named `x.html` whose `data:` payload contains `<script>`
- **THEN** no file is ever created at `public/tmp/{site_id}/x.html`, so a concurrent request for `/tmp/{site_id}/x.html` cannot retrieve the payload at any point

#### Scenario: An already-published file can be re-cropped
- **WHEN** a file that is already stored under `Rails.public_path` is used as the source of a crop
- **THEN** the crop proceeds without the source being re-scanned

#### Scenario: A private-media source is still scanned
- **WHEN** a file outside the public root (for example under the private-media directory) is used as an upload source
- **THEN** the content scan runs as before

### Requirement: Content is normalized before pattern matching

The system SHALL normalize file content before matching it against the malicious-content patterns, so that encoded variants of a blocked pattern are detected. Normalization SHALL decode HTML entities repeatedly up to a bounded number of passes, remove NUL and control characters, and tolerate — inside a URI scheme name — exactly the characters browsers strip when parsing a URL: TAB, LF and CR. Other whitespace, notably the space character, SHALL NOT be tolerated inside a scheme, so ordinary prose in which a blocked scheme word is followed by a space and a colon is not reported as malicious.

#### Scenario: Hex-entity encoded javascript scheme is rejected
- **WHEN** a user uploads a non-SVG file containing `<a href="jav&#x61;script:alert(1)">`
- **THEN** the system returns `'Potentially malicious content found!'`

#### Scenario: Decimal-entity encoded javascript scheme is rejected
- **WHEN** a user uploads a non-SVG file containing `<a href="&#106;avascript:alert(1)">`
- **THEN** the system returns `'Potentially malicious content found!'`

#### Scenario: Tab inside a URI scheme is rejected
- **WHEN** a user uploads a non-SVG file containing a `javascript:` URI with a TAB character inside the scheme name
- **THEN** the system returns `'Potentially malicious content found!'`

#### Scenario: Newline inside a URI scheme is rejected
- **WHEN** a user uploads a non-SVG file containing a `javascript:` URI with a LF character inside the scheme name
- **THEN** the system returns `'Potentially malicious content found!'`

#### Scenario: NUL byte inside a URI scheme is rejected
- **WHEN** a user uploads a non-SVG file containing a `javascript:` URI with a NUL byte inside the scheme name
- **THEN** the system returns `'Potentially malicious content found!'`

#### Scenario: Double-encoded entity is rejected
- **WHEN** a user uploads a non-SVG file whose content decodes to a blocked pattern only after more than one entity-decoding pass
- **THEN** the system returns `'Potentially malicious content found!'`

#### Scenario: Entity decoding is bounded
- **WHEN** content is normalized
- **THEN** decoding stops after at most 5 passes, matching the bound used by `UserUrlValidator#validate_path_traversal`, rather than looping until stable

#### Scenario: Escaped code examples are rejected as a fail-closed consequence
- **WHEN** a user uploads a non-SVG file containing HTML-escaped markup such as `<p>Use &lt;script&gt; carefully</p>`
- **THEN** the system returns `'Potentially malicious content found!'`, because normalization decodes the entities before matching

#### Scenario: Plain non-markup content is unaffected
- **WHEN** a user uploads a plain text, CSV, or JSON file containing no blocked pattern
- **THEN** the upload is accepted

#### Scenario: Prose containing a scheme word before a spaced colon is accepted
- **WHEN** a user uploads a text file containing `Sample data : 42`
- **THEN** the upload is accepted, because a space is not a character browsers strip from a URI scheme
