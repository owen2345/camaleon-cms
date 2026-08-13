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

The system SHALL reject SVG uploads whose `href`/`xlink:href` attributes, or whose serialized markup,
contain a blocked URI scheme. `javascript:` and `vbscript:` are always blocked; a `data:` URI is
blocked unless its media type is an allowlisted raster image (for example `image/png`, `image/gif`,
`image/jpeg`, `image/webp`), so an embedded raster bitmap is accepted while `data:text/html`,
`data:image/svg+xml`, and a bare `data:,…` are rejected. Detection SHALL tolerate the same
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

#### Scenario: An embedded raster image is accepted
- **WHEN** a user uploads an SVG containing `<image xlink:href="data:image/png;base64,…"/>` (an embedded raster bitmap)
- **THEN** the system stores the file normally

#### Scenario: A dangerous data: URI is rejected
- **WHEN** a user uploads an SVG containing a `data:text/html` or `data:image/svg+xml` URI (which can carry active content)
- **THEN** the system returns an error and does NOT store the file

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

The SMIL animation elements `animate` and `set` SHALL be treated as safe elements: they carry no script by themselves, and the scripting risk they were associated with is the `onbegin`/`onend`/`onrepeat` event-handler attributes, which the event-handler rule continues to reject independently of the element they appear on. Elements that embed foreign content or handlers — `script`, `foreignObject`, `handler`, `iframe`, `object`, `embed` — remain rejected.

The elements `form`, `meta`, `base`, `style` and `link` SHALL also be rejected. Each is valid in SVG and none executes script on its own, but an uploaded SVG is served inline from the site origin, and these five are what turn a passive image into markup that can navigate (`meta http-equiv="refresh"`, `base href`), collect input (`form`), or pull in remote styling (`link`, `style`). `ContentSecurity::BLOCKED_ELEMENTS` already refuses all five in every non-SVG upload; rejecting them here too means the SVG and non-SVG rulesets no longer disagree about the same bytes, so re-uploading a file under a different extension cannot reach a more permissive ruleset.

#### Scenario: Safe SVG without dangerous content is accepted
- **WHEN** a user uploads an SVG file with no script elements, event handlers, or javascript: URIs
- **THEN** the system stores the file normally

#### Scenario: Animated SVG without event handlers is accepted
- **WHEN** a user uploads an SVG containing `<circle><animate attributeName="r" values="1;2" dur="1s"/></circle>` and no event-handler attributes
- **THEN** the system stores the file normally

#### Scenario: A `set` element without event handlers is accepted
- **WHEN** a user uploads an SVG containing `<set attributeName="fill" to="blue"/>` and no event-handler attributes
- **THEN** the system stores the file normally

#### Scenario: An animation element carrying an event handler is still rejected
- **WHEN** a user uploads an SVG containing `<animate onbegin="alert(1)"/>`
- **THEN** the system returns an error and does NOT store the file

#### Scenario: foreignObject remains rejected
- **WHEN** a user uploads an SVG containing a `<foreignObject>` element
- **THEN** the system returns an error and does NOT store the file

#### Scenario: An SVG carrying a form is rejected
- **WHEN** a user uploads an SVG containing a `<form>` element
- **THEN** the system returns an error and does NOT store the file

#### Scenario: An SVG carrying a meta refresh is rejected
- **WHEN** a user uploads an SVG containing a `<meta http-equiv="refresh">` element
- **THEN** the system returns an error and does NOT store the file

#### Scenario: An SVG carrying a base element is rejected
- **WHEN** a user uploads an SVG containing a `<base>` element
- **THEN** the system returns an error and does NOT store the file

#### Scenario: An SVG carrying a style element is rejected
- **WHEN** a user uploads an SVG containing a `<style>` element
- **THEN** the system returns an error and does NOT store the file

#### Scenario: An SVG carrying a link element is rejected
- **WHEN** a user uploads an SVG containing a `<link>` element
- **THEN** the system returns an error and does NOT store the file

### Requirement: XML parse errors reject the upload

The system SHALL reject SVG uploads that fail to parse as valid XML.

#### Scenario: Malformed SVG is rejected
- **WHEN** a user uploads a file that cannot be parsed as valid XML
- **THEN** the system returns an error and does NOT store the file

