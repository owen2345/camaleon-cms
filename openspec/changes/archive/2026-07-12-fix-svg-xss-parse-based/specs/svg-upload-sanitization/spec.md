## Purpose

Define the security requirements for detecting dangerous content in uploaded SVG files. SVG files MUST be parsed with an XML parser that resolves all entities, and the upload MUST be rejected if dangerous elements or attributes are present. Safe SVGs without dangerous content are accepted.

## Requirements

### Requirement: Reject SVGs with script elements

The system SHALL reject SVG uploads that contain `<script>` elements.

#### Scenario: SVG with script tag is rejected
- **WHEN** a user uploads an SVG file containing a `<script>` element
- **THEN** the system returns an error and does NOT store the file

### Requirement: Reject SVGs with event handler attributes

The system SHALL reject SVG uploads that contain attributes starting with `on` (event handlers).

#### Scenario: SVG with onclick is rejected
- **WHEN** a user uploads an SVG file containing an `onclick` attribute
- **THEN** the system returns an error and does NOT store the file

#### Scenario: SVG with onpointerdown is rejected
- **WHEN** a user uploads an SVG file containing an `onpointerdown` attribute
- **THEN** the system returns an error and does NOT store the file

#### Scenario: SVG with onbegin animation event is rejected
- **WHEN** a user uploads an SVG file containing an `onbegin` attribute on an `<animate>` element
- **THEN** the system returns an error and does NOT store the file

### Requirement: Reject SVGs with javascript: URIs

The system SHALL reject SVG uploads that contain `href` or `xlink:href` attributes with `javascript:` URIs. Entity-encoded variants are caught because XML parsing resolves all entities before inspection.

#### Scenario: SVG with javascript: in href is rejected
- **WHEN** a user uploads an SVG file containing an `href` attribute with `javascript:` URI
- **THEN** the system returns an error and does NOT store the file

#### Scenario: SVG with entity-encoded javascript: in href is rejected
- **WHEN** a user uploads an SVG file containing `href="javascript&#58;alert(1)"`
- **THEN** the system returns an error and does NOT store the file (entity is resolved during XML parsing, javascript: is detected)

### Requirement: Reject SVGs with DTD entities containing dangerous content

The system SHALL reject SVG uploads that use internal DTD entities to inject dangerous content. XML parsing resolves all entities, allowing the expanded content to be inspected.

#### Scenario: SVG with DTD entity containing script tag is rejected
- **WHEN** a user uploads an SVG file with `<!ENTITY x "<script>alert(1)</script>">` and `&x;` in the body
- **THEN** the system returns an error and does NOT store the file (entity is expanded during parsing, script element is detected)

#### Scenario: SVG with DTD entity containing javascript: is rejected
- **WHEN** a user uploads an SVG file with `<!ENTITY xlink "javascript:">` and `xlink:href="&xlink;alert(1)"`
- **THEN** the system returns an error and does NOT store the file (entity is expanded during parsing, javascript: URI is detected)

### Requirement: Safe SVGs are accepted

The system SHALL accept SVG uploads that contain no dangerous elements, attributes, or URIs.

#### Scenario: Safe SVG without dangerous content is accepted
- **WHEN** a user uploads an SVG file with no script elements, event handlers, or javascript: URIs
- **THEN** the system stores the file normally

### Requirement: XML parse errors reject the upload

The system SHALL reject SVG uploads that fail to parse as valid XML.

#### Scenario: Malformed SVG is rejected
- **WHEN** a user uploads a file that cannot be parsed as valid XML
- **THEN** the system returns an error and does NOT store the file
