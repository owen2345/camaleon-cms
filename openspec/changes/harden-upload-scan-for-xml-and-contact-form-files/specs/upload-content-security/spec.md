## MODIFIED Requirements

### Requirement: Content is normalized before pattern matching

The system SHALL normalize file content before it matches the content against the malicious-content patterns, so that encoded variants of a blocked pattern are detected. Normalization SHALL decode HTML entities repeatedly, up to a bounded number of passes, and SHALL remove NUL and control characters. It SHALL also decode the named references `&colon;`, `&Tab;`, `&NewLine;`, `&sol;`, `&semi;`, `&comma;`, `&period;` and `&plus;`.

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

#### Scenario: A scheme whose colon is a named reference is rejected
- **WHEN** a user uploads an `.html` file containing `<a href="javascript&colon;alert(1)">`
- **THEN** the system returns `'Potentially malicious content found!'`
- **AND** the same holds for `java&Tab;script:alert(1)` and `java&NewLine;script:alert(1)`
- **AND** the same holds for the link in a `.txt` file

#### Scenario: A data URI whose slash is a named reference is rejected
- **WHEN** a user uploads an `.html` file containing `<a href="data:text&sol;html,text">`
- **THEN** the system returns `'Potentially malicious content found!'`

#### Scenario: A named reference in an XML file with a public XHTML DOCTYPE is rejected
- **WHEN** a user uploads an `.xhtml` file with the public XHTML 1.0 Strict DOCTYPE and `<a href="javascript&colon;alert(1)">`
- **THEN** the system returns `'Potentially malicious content found!'`
- **AND** the same holds for that file in UTF-16, and for an `.svg` file with that DOCTYPE and that link
- **AND** the same holds for that file in ISO-2022-JP, when the escape sequence `ESC ( B` or `ESC ( J` splits `&colon;`

#### Scenario: A named reference with no scheme is accepted
- **WHEN** a user uploads an `.html` file containing `<p>Open&colon; 10&colon;30</p>` and no blocked pattern
- **THEN** the upload is accepted
- **AND** the same holds for that text in an `.xhtml` file with the public XHTML 1.0 Strict DOCTYPE

#### Scenario: A name that a browser does not read is not decoded
- **WHEN** content with `javascript&COLON;` or with `javascript&colon` and no semicolon is normalized
- **THEN** the normalization keeps that text as it is

## ADDED Requirements

### Requirement: The re-examination task scans the contact form uploads

The task SHALL also scan the whole folder `public/contact_form`. The contact form plugin stores the
files of visitors there, under the id of each site, and a visitor gets the upload scan. A report
without that folder leaves out the files of the users that the scan trusts least. The scan SHALL
include a folder whose id belongs to no site, because the folder of a deleted site can stay.

#### Scenario: A flagged contact form file is reported
- **WHEN** the task runs with a file under `public/contact_form/<site id>` that the current rules refuse
- **THEN** the file is listed in the report, with the id of its site in its path

#### Scenario: A contact form file that passes is counted
- **WHEN** the task runs with a file under `public/contact_form/<site id>` that the current rules accept
- **THEN** the report counts the file as scanned and does not list it

#### Scenario: A file in the folder of a deleted site is reported
- **WHEN** the task runs with a file that the current rules refuse, under `public/contact_form/<id>` with an id that no site has
- **THEN** the file is listed in the report

#### Scenario: A site with no contact form folder is scanned
- **WHEN** the task runs for a site that has no folder under `public/contact_form`
- **THEN** the task reports the media files of that site and raises no error
