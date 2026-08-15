## Purpose

Define the security requirements for detecting dangerous content in uploaded SVG files. SVG files MUST be parsed with an XML parser that resolves all entities, and the upload MUST be rejected if dangerous elements or attributes are present. Safe SVGs without dangerous content are accepted.
## Requirements
### Requirement: Reject SVGs with script elements

The system SHALL reject SVG uploads that contain `<script>` elements.

#### Scenario: SVG with script tag is rejected
- **WHEN** a user uploads an SVG file containing a `<script>` element
- **THEN** the system returns an error and does NOT store the file

### Requirement: Reject SVGs with event handler attributes

The system SHALL reject SVG uploads that contain attributes whose name starts with `on` (event
handlers). The match SHALL be case-insensitive, because an SVG inlined into an HTML document fires
`ONCLICK`/`OnClick` exactly as `onclick`, matching the case-insensitive event-handler rule used for
non-SVG uploads.

#### Scenario: SVG with onclick is rejected
- **WHEN** a user uploads an SVG file containing an `onclick` attribute
- **THEN** the system returns an error and does NOT store the file

#### Scenario: SVG with an uppercase/mixed-case event handler is rejected
- **WHEN** a user uploads an SVG file containing an `ONCLICK` or `OnMouseOver` attribute
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
the only gate for a served `.svg`, so it aligns with the non-SVG ruleset's scheme, element, and
(case-insensitive) event-handler checks as defense-in-depth. It inspects the XML-parsed document,
exactly as a browser does when serving `image/svg+xml`; a *literal* TAB/LF/CR that XML attribute-value
normalization folds to a space — making the scheme inert when the file is served as an image — is
therefore out of scope, unlike the entity/character-reference gaps above, which survive parsing and are
caught.

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

The system SHALL reject uploads in an XML-parsed markup format that fail to parse as valid XML. A
file that does not parse is not a valid document of that format, so refusing it fails closed.

This signal SHALL NOT be relied upon for HTML-parsed formats. An HTML parser accepts any byte
sequence and never reports a parse error, so there is no parse-failure signal available in that
mode; HTML-parsed uploads are decided entirely by the rejection rules applied to the resulting tree.

#### Scenario: Malformed SVG is rejected
- **WHEN** a user uploads a `.svg` file that cannot be parsed as valid XML
- **THEN** the system returns an error and does NOT store the file

#### Scenario: Malformed XHTML is rejected
- **WHEN** a user uploads an `.xhtml` file that cannot be parsed as valid XML
- **THEN** the system returns an error and does NOT store the file

#### Scenario: Malformed HTML is judged on its content, not on parse success
- **WHEN** a user uploads an `.html` file that is not well-formed but contains no handlers, script, blocked elements or blocked schemes
- **THEN** the system stores the file normally, because parse failure is not available as a signal in HTML mode

#### Scenario: Malformed HTML carrying a handler is still rejected
- **WHEN** a user uploads a badly nested `.html` file that contains an `onpointerdown` attribute
- **THEN** the system returns an error and does NOT store the file

### Requirement: The parse-based checker governs every markup format, not only SVG

Every requirement in this capability SHALL apply to any upload a browser parses as markup, not only
to files named `.svg`. The rejection rules — script elements, attributes whose name begins with
`on`, blocked URI schemes, entity-expanded content, and the navigating/embedding elements `form`,
`meta`, `base`, `style`, `link`, `foreignObject`, `handler`, `iframe`, `object` and `embed` — are the
same for an HTML, XHTML, XML or XSL upload as for an SVG.

The checker SHALL reject event handlers by shape: any attribute whose name begins with `on`,
case-insensitively. It SHALL NOT decide event handlers by matching a list of known handler names,
because such a list is unbounded and grows with the web platform.

Which uploads reach this checker is specified by `upload-content-security`.

#### Scenario: An HTML upload with an unlisted handler is rejected
- **WHEN** an `.html` upload contains an `onpointerdown` attribute
- **THEN** the checker reports it unsafe and the upload is not stored

#### Scenario: A future handler name needs no rule change
- **WHEN** an `.html` upload contains an attribute named `onsomethingnotyetinvented`
- **THEN** the checker reports it unsafe, because the match is on the `on` prefix and not on a name list

#### Scenario: An XHTML upload carrying a script element is rejected
- **WHEN** an `.xhtml` upload contains a `<script>` element
- **THEN** the checker reports it unsafe and the upload is not stored

#### Scenario: An XML upload carrying a blocked scheme is rejected
- **WHEN** an `.xml` upload contains an `href` attribute with a `javascript:` URI
- **THEN** the checker reports it unsafe and the upload is not stored

#### Scenario: Clean markup is accepted
- **WHEN** an `.html` upload contains ordinary formatting markup with no handlers, script, blocked elements or blocked schemes
- **THEN** the checker reports it safe and the upload is stored normally

### Requirement: HTML-family markup is evaluated with an HTML parser

The system SHALL parse `html`, `htm` and `shtml` uploads with an HTML parser rather than an XML
parser, because an HTML document is not well-formed XML and an XML parse would reject or misread it.
The XML parser SHALL remain in use for `svg`, `svgz`, `xhtml`, `xht`, `xml`, `xsl` and `xslt`.

Both parse modes SHALL apply the same rejection rules, so the verdict for a given payload does not
depend on which parser read it.

#### Scenario: A structurally ordinary HTML document is not rejected merely for being HTML
- **WHEN** an `.html` upload contains unclosed `<p>` tags, an implicit `<tbody>`, or attribute values without quotes
- **THEN** the checker does not reject it for those reasons alone

#### Scenario: HTML comments do not cause rejection
- **WHEN** an `.html` upload contains an ordinary HTML comment
- **THEN** the checker does not reject it for the comment

#### Scenario: The same payload gets the same verdict in either mode
- **WHEN** identical event-handler markup is scanned once as `.html` and once as `.xhtml`
- **THEN** both are reported unsafe

