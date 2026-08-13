## MODIFIED Requirements

### Requirement: Reject SVGs with javascript: URIs

The system SHALL reject SVG uploads whose `href`/`xlink:href` attributes, or whose serialized markup,
contain a blocked URI scheme (`javascript:`, `vbscript:`, `data:`). Detection SHALL tolerate the same
TAB/LF/CR gaps *inside* the scheme that a browser strips before executing the URI (for example
`java&#9;script:`), matching `ContentSecurity::BLOCKED_SCHEME_PATTERN` used for non-SVG uploads.
Entity-encoded variants are caught because XML parsing resolves entities into the decoded attribute
value, and the serialized document is entity-decoded (normalized) before inspection. The SVG scanner is
the only gate for a served `.svg`, so it SHALL NOT be more permissive than the non-SVG ruleset about
the same bytes.

#### Scenario: SVG with javascript: in href is rejected
- **WHEN** a user uploads an SVG file containing an `href` attribute with `javascript:` URI
- **THEN** the system returns an error and does NOT store the file

#### Scenario: SVG with entity-encoded javascript: in href is rejected
- **WHEN** a user uploads an SVG file containing `href="javascript&#58;alert(1)"`
- **THEN** the system returns an error and does NOT store the file (entity is resolved during XML parsing, javascript: is detected)

#### Scenario: SVG with an in-scheme TAB/LF/CR gap in href is rejected
- **WHEN** a user uploads an SVG file containing `href="java&#9;script:alert(1)"` (a TAB inside the scheme name)
- **THEN** the system returns an error and does NOT store the file

#### Scenario: An auto-triggering animated gap-scheme href is rejected
- **WHEN** a user uploads an SVG containing `<a xlink:href="java&#9;script:alert(1)"><animate begin="0s"/></a>`
- **THEN** the system returns an error and does NOT store the file

#### Scenario: A gap-obfuscated scheme anywhere in the serialized document is rejected
- **WHEN** a user uploads an SVG in which a blocked scheme with a TAB/LF/CR gap appears outside an `href` (for example in text content)
- **THEN** the system returns an error and does NOT store the file

#### Scenario: A safe SVG whose text merely contains a colon is accepted
- **WHEN** a user uploads an SVG whose text is prose containing a colon but no blocked scheme (for example `Fig 1: a red circle`)
- **THEN** the system stores the file normally
