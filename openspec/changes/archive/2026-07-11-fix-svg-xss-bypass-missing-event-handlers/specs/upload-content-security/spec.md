## ADDED Requirements

### Requirement: Reject uploaded files with event handler attributes

The system SHALL reject file uploads whose content contains known executable event handler attributes before storing or persisting the file.

#### Scenario: File with `onclick` is rejected
- **WHEN** a user uploads a file whose content includes an `onclick` attribute
- **THEN** the system returns `'Potentially malicious content found!'` and does NOT persist the file

#### Scenario: File with `onload` is rejected
- **WHEN** a user uploads a file whose content includes an `onload` attribute
- **THEN** the system returns `'Potentially malicious content found!'` and does NOT persist the file

#### Scenario: File with `onbegin` is rejected
- **WHEN** a user uploads an SVG whose content includes `<animate onbegin="...">`
- **THEN** the system returns `'Potentially malicious content found!'` and does NOT persist the file

#### Scenario: File with `onend` is rejected
- **WHEN** a user uploads an SVG whose content includes `<animate onend="...">`
- **THEN** the system returns `'Potentially malicious content found!'` and does NOT persist the file

#### Scenario: File with `onrepeat` is rejected
- **WHEN** a user uploads an SVG whose content includes `<animate onrepeat="...">`
- **THEN** the system returns `'Potentially malicious content found!'` and does NOT persist the file

#### Scenario: Safe SVG without event handlers is accepted
- **WHEN** a user uploads an SVG file with no executable content patterns
- **THEN** the system accepts and persists the file successfully

### Requirement: Reject uploaded files with `<script>` tags

The system SHALL reject file uploads whose content contains `<script>` elements.

#### Scenario: SVG with `<script>` is rejected
- **WHEN** a user uploads an SVG file containing a `<script>` tag
- **THEN** the system returns `'Potentially malicious content found!'` and does NOT persist the file

### Requirement: Reject uploaded files with `javascript:` URIs

The system SHALL reject file uploads whose content contains `javascript:` URIs in attributes.

#### Scenario: File with `javascript:` in href is rejected
- **WHEN** a user uploads a file containing `javascript:` in an href or src attribute
- **THEN** the system returns `'Potentially malicious content found!'` and does NOT persist the file

### Requirement: Safe file scanning does not consume the IO stream

After scanning for malicious content, the file pointer SHALL be rewound so subsequent consumers can read the full content.

#### Scenario: Tempfile is readable after scan
- **WHEN** the system scans a Tempfile for unsafe content and the scan passes
- **THEN** the Tempfile pointer is at the beginning and the full content can be read again
