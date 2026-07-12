## Purpose

Define the security requirements for content scanning of uploaded files. Uploaded files MUST be scanned for executable content patterns before being persisted, to prevent stored XSS attacks via uploaded files.

## Requirements

### Requirement: Reject uploaded files with event handler attributes

The system SHALL reject file uploads whose content contains known executable event handler attributes before storing or persisting the file.

**Change**: SVG files are no longer scanned for event handlers using the regex denylist — SVG content checks are handled by the XML parse-based checker in the `svg-upload-sanitization` capability. Non-SVG files continue to be scanned by the regex pipeline.

#### Scenario: Non-SVG file with onclick is rejected
- **WHEN** a user uploads a non-SVG file whose content includes an `onclick` attribute
- **THEN** the system returns `'Potentially malicious content found!'` and does NOT persist the file

#### Scenario: Non-SVG file with onload is rejected
- **WHEN** a user uploads a non-SVG file whose content includes an `onload` attribute
- **THEN** the system returns `'Potentially malicious content found!'` and does NOT persist the file

#### Scenario: SVG with event handlers is rejected (not scanned by regex)
- **WHEN** a user uploads an SVG file containing event handler attributes
- **THEN** the system rejects the upload via the parse-based checker (see `svg-upload-sanitization`)

### Requirement: Reject uploaded files with `<script>` tags

The system SHALL reject file uploads whose content contains `<script>` elements.

**Change**: SVG `<script>` elements are handled by the XML parse-based checker; non-SVG files continue to use the regex denylist.

#### Scenario: Non-SVG with `<script>` is rejected
- **WHEN** a user uploads a non-SVG file containing a `<script>` tag
- **THEN** the system returns `'Potentially malicious content found!'` and does NOT persist the file

### Requirement: Reject uploaded files with `javascript:` URIs

The system SHALL reject file uploads whose content contains `javascript:` URIs in attributes.

**Change**: SVG `javascript:` URIs are handled by the XML parse-based checker; non-SVG files continue to use the regex denylist.

#### Scenario: Non-SVG with javascript: in href is rejected
- **WHEN** a user uploads a non-SVG file containing `javascript:` in an href or src attribute
- **THEN** the system returns `'Potentially malicious content found!'` and does NOT persist the file

### Requirement: Safe file scanning does not consume the IO stream

After scanning for malicious content, the file pointer SHALL be rewound so subsequent consumers can read the full content.

*(Unchanged — applies to all file types)*

#### Scenario: Tempfile is readable after scan
- **WHEN** the system scans a Tempfile for unsafe content and the scan passes
- **THEN** the Tempfile pointer is at the beginning and the full content can be read again
