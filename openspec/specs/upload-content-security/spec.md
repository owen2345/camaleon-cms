## Purpose

Define the security requirements for content scanning of uploaded files. Uploaded files MUST be scanned for executable content patterns before being persisted, to prevent stored XSS attacks via uploaded files.

## Requirements

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

### Requirement: Content scanning is available for in-memory content

The system SHALL expose a content-scanning entry point that accepts content and a filename directly, in addition to the existing IO-based entry point, so callers holding decoded bytes can scan without first writing them to disk. Both entry points SHALL apply the same detection logic — parse-based checking for SVG, normalized pattern matching otherwise.

#### Scenario: String scan matches IO scan for the same bytes
- **WHEN** the same content is scanned once as an in-memory String and once through a file handle
- **THEN** both scans return the same verdict

#### Scenario: SVG content passed as a String uses the parse-based checker
- **WHEN** SVG content containing an event handler is scanned as an in-memory String with an `.svg` filename
- **THEN** the scan reports the content as unsafe

#### Scenario: IO entry point still rewinds
- **WHEN** content is scanned through the IO-based entry point and the scan passes
- **THEN** the IO pointer is at the beginning and the full content can be read again

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

### Requirement: Reject uploaded files with event handler attributes

The system SHALL reject file uploads whose content contains known executable event handler attributes before storing or persisting the file. Rejection SHALL leave no copy of the file on disk, including the copy in the upload staging directory.

**Change**: SVG files are no longer scanned for event handlers using the regex denylist — SVG content checks are handled by the XML parse-based checker in the `svg-upload-sanitization` capability. Non-SVG files continue to be scanned by the regex pipeline, now applied to normalized content.

#### Scenario: Non-SVG file with onclick is rejected
- **WHEN** a user uploads a non-SVG file whose content includes an `onclick` attribute
- **THEN** the system returns `'Potentially malicious content found!'` and does NOT persist the file

#### Scenario: Non-SVG file with onload is rejected
- **WHEN** a user uploads a non-SVG file whose content includes an `onload` attribute
- **THEN** the system returns `'Potentially malicious content found!'` and does NOT persist the file

#### Scenario: SVG with event handlers is rejected (not scanned by regex)
- **WHEN** a user uploads an SVG file containing event handler attributes
- **THEN** the system rejects the upload via the parse-based checker (see `svg-upload-sanitization`)

#### Scenario: Rejected file is absent from the staging directory
- **WHEN** an upload is rejected for containing an event-handler attribute
- **THEN** no file for that upload remains under `public/tmp/{site_id}/`

### Requirement: Reject uploaded files with `<script>` tags

The system SHALL reject file uploads whose content contains `<script>` elements. Rejection SHALL leave no copy of the file on disk, including the copy in the upload staging directory.

**Change**: SVG `<script>` elements are handled by the XML parse-based checker; non-SVG files continue to use the regex denylist, now applied to normalized content and tolerant of `/` as a tag delimiter.

#### Scenario: Non-SVG with `<script>` is rejected
- **WHEN** a user uploads a non-SVG file containing a `<script>` tag
- **THEN** the system returns `'Potentially malicious content found!'` and does NOT persist the file

#### Scenario: Rejected `<script>` payload is never written to the staging path
- **WHEN** a media-permission user posts a `crop_url` upload named `x.html` whose `data:` payload contains `<script>`
- **THEN** the system returns `'Potentially malicious content found!'`
- **AND** no file is created at `public/tmp/{site_id}/x.html` at any point during the request

### Requirement: Reject uploaded files with `javascript:` URIs

The system SHALL reject file uploads whose content contains `javascript:` URIs in attributes, including entity-encoded and whitespace-interrupted forms of the scheme. Rejection SHALL leave no copy of the file on disk, including the copy in the upload staging directory.

**Change**: SVG `javascript:` URIs are handled by the XML parse-based checker; non-SVG files continue to use the regex denylist, now applied to normalized content.

#### Scenario: Non-SVG with javascript: in href is rejected
- **WHEN** a user uploads a non-SVG file containing `javascript:` in an href or src attribute
- **THEN** the system returns `'Potentially malicious content found!'` and does NOT persist the file

### Requirement: Reject uploaded files containing `vbscript:` URIs

The system SHALL reject file uploads whose content contains `vbscript:` URIs, matching the schemes already blocked by the SVG parse-based checker.

#### Scenario: Non-SVG with vbscript: in href is rejected
- **WHEN** a user uploads a non-SVG file containing `<a href="vbscript:msgbox(1)">`
- **THEN** the system returns `'Potentially malicious content found!'` and does NOT persist the file

### Requirement: Blocked element detection tolerates alternative tag delimiters

The system SHALL treat `/` as a tag-name delimiter in addition to whitespace and `>`, so a blocked element cannot evade detection by using a slash immediately after the tag name.

#### Scenario: Slash-delimited script tag is rejected
- **WHEN** a user uploads a non-SVG file containing `<script/src="//evil.tld"></script>`
- **THEN** the system returns `'Potentially malicious content found!'` and does NOT persist the file

### Requirement: Reject additional dangerous elements

The system SHALL reject file uploads whose content contains elements able to navigate, exfiltrate, or load remote active content, in addition to the elements already blocked: `meta`, `style`, `form`, `applet`, `frame`, `frameset`, `link`, `template`, `portal`, `marquee`, and `math`.

#### Scenario: Meta refresh redirect is rejected
- **WHEN** a user uploads a non-SVG file containing `<meta http-equiv="refresh" content="0;url=//evil.tld">`
- **THEN** the system returns `'Potentially malicious content found!'` and does NOT persist the file

#### Scenario: Style element with remote import is rejected
- **WHEN** a user uploads a non-SVG file containing `<style>@import "//evil.tld/x.css";</style>`
- **THEN** the system returns `'Potentially malicious content found!'` and does NOT persist the file

#### Scenario: Form with remote action is rejected
- **WHEN** a user uploads a non-SVG file containing `<form action="//evil.tld">`
- **THEN** the system returns `'Potentially malicious content found!'` and does NOT persist the file

#### Scenario: Applet element is rejected
- **WHEN** a user uploads a non-SVG file containing `<applet code="Evil.class">`
- **THEN** the system returns `'Potentially malicious content found!'` and does NOT persist the file

#### Scenario: Frameset and frame elements are rejected
- **WHEN** a user uploads a non-SVG file containing `<frameset><frame src="//evil.tld">`
- **THEN** the system returns `'Potentially malicious content found!'` and does NOT persist the file

### Requirement: Safe file scanning does not consume the IO stream

After scanning for malicious content, the file pointer SHALL be rewound so subsequent consumers can read the full content.

*(Unchanged — applies to all file types)*

#### Scenario: Tempfile is readable after scan
- **WHEN** the system scans a Tempfile for unsafe content and the scan passes
- **THEN** the Tempfile pointer is at the beginning and the full content can be read again
