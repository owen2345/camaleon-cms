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

The system SHALL reject SVG uploads whose `href`/`xlink:href` attributes, or whose serialized markup, contain a blocked URI scheme. `javascript:` and `vbscript:` are always blocked. A `data:` URI is blocked unless its media type is an allowlisted raster image.

#### Scenario: SVG with javascript: in href is rejected
- **WHEN** a user uploads an SVG file containing an `href` attribute with `javascript:` URI
- **THEN** the system returns an error and does NOT store the file

#### Scenario: An embedded raster image is accepted
- **WHEN** a user uploads an SVG containing `<image xlink:href="data:image/png;base64,…"/>` (an embedded raster bitmap)
- **THEN** the system stores the file normally
- **AND** the allowlisted raster media types are, for example, `image/png`, `image/gif`, `image/jpeg` and `image/webp`

#### Scenario: A dangerous data: URI is rejected
- **WHEN** a user uploads an SVG containing a `data:text/html` or `data:image/svg+xml` URI (which can carry active content)
- **THEN** the system returns an error and does NOT store the file

#### Scenario: A bare data: URI is rejected
- **WHEN** a user uploads an SVG containing a bare `data:,…` URI
- **THEN** the system returns an error and does NOT store the file

### Requirement: Scheme detection tolerates gaps inside the scheme

Detection SHALL tolerate the same TAB/LF/CR gaps *inside* the scheme that a browser strips before executing the URI (for example `java&#9;script:`). This matches `ContentSecurity::BLOCKED_SCHEME_PATTERN`, which the system uses for non-SVG uploads.

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

### Requirement: Entity-encoded scheme variants are caught

The scanner SHALL catch entity-encoded variants of a blocked scheme. XML parsing resolves entities into the decoded attribute value. The scanner SHALL entity-decode (normalize) the serialized document before inspection.

#### Scenario: SVG with entity-encoded javascript: in href is rejected
- **WHEN** a user uploads an SVG file containing `href="javascript&#58;alert(1)"`
- **THEN** the system returns an error and does NOT store the file (entity is resolved during XML parsing, javascript: is detected)

### Requirement: The SVG scanner aligns with the non-SVG ruleset

The SVG scanner is the only gate for a served `.svg`. It SHALL align with the scheme, element, and (case-insensitive) event-handler checks of the non-SVG ruleset, as defense-in-depth.

#### Scenario: A construct that the non-SVG ruleset refuses is refused in SVG
- **WHEN** a user uploads an SVG that contains a scheme, element or event handler that the non-SVG ruleset refuses
- **THEN** the system returns an error and does NOT store the file

### Requirement: The scanner inspects the XML-parsed document

The SVG scanner SHALL inspect the XML-parsed document, exactly as a browser does when it serves `image/svg+xml`. Entity and character-reference gaps survive parsing, so the scanner SHALL catch them. A *literal* TAB/LF/CR that XML attribute-value normalization folds to a space is out of scope.

#### Scenario: A literal gap folded by XML normalization is out of scope
- **WHEN** a user uploads an SVG whose attribute value has a literal TAB, LF or CR inside the scheme
- **AND** XML attribute-value normalization folds it to a space
- **THEN** the scanner is not required to reject the file
- **AND** the reason is that the folded scheme is inert when the file is served as an image

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

#### Scenario: Animated SVG without event handlers is accepted
- **WHEN** a user uploads an SVG containing `<circle><animate attributeName="r" values="1;2" dur="1s"/></circle>` and no event-handler attributes
- **THEN** the system stores the file normally

#### Scenario: A `set` element without event handlers is accepted
- **WHEN** a user uploads an SVG containing `<set attributeName="fill" to="blue"/>` and no event-handler attributes
- **THEN** the system stores the file normally

### Requirement: SMIL animation elements are safe elements

The SMIL animation elements `animate` and `set` SHALL be treated as safe elements, because they carry no script by themselves. The event-handler rule SHALL reject the `onbegin`/`onend`/`onrepeat` attributes on any element. Elements that embed foreign content or handlers (`script`, `foreignObject`, `handler`, `iframe`, `object`, `embed`) SHALL remain rejected.

#### Scenario: An animation element carrying an event handler is still rejected
- **WHEN** a user uploads an SVG containing `<animate onbegin="alert(1)"/>`
- **THEN** the system returns an error and does NOT store the file
- **AND** the scripting risk of these elements is the event-handler attributes, which the event-handler rule rejects independently of the element

#### Scenario: foreignObject remains rejected
- **WHEN** a user uploads an SVG containing a `<foreignObject>` element
- **THEN** the system returns an error and does NOT store the file

### Requirement: Navigating, input and styling elements are rejected

The elements `form`, `meta`, `base`, `style` and `link` SHALL be rejected. `ContentSecurity::BLOCKED_ELEMENTS` already refuses all five in every non-SVG upload, so the SVG and non-SVG rulesets SHALL NOT disagree about the same bytes. The system serves an uploaded SVG inline from the site origin.

#### Scenario: An SVG carrying a form is rejected
- **WHEN** a user uploads an SVG containing a `<form>` element
- **THEN** the system returns an error and does NOT store the file
- **AND** the reason is that `form` can collect input

#### Scenario: An SVG carrying a meta refresh is rejected
- **WHEN** a user uploads an SVG containing a `<meta http-equiv="refresh">` element
- **THEN** the system returns an error and does NOT store the file
- **AND** the reason is that `meta http-equiv="refresh"` can navigate

#### Scenario: An SVG carrying a base element is rejected
- **WHEN** a user uploads an SVG containing a `<base>` element
- **THEN** the system returns an error and does NOT store the file
- **AND** the reason is that `base href` can navigate

#### Scenario: An SVG carrying a style element is rejected
- **WHEN** a user uploads an SVG containing a `<style>` element
- **THEN** the system returns an error and does NOT store the file
- **AND** the reason is that `style` can pull in remote styling

#### Scenario: An SVG carrying a link element is rejected
- **WHEN** a user uploads an SVG containing a `<link>` element
- **THEN** the system returns an error and does NOT store the file
- **AND** the reason is that `link` can pull in remote styling

#### Scenario: A different extension reaches no more permissive ruleset
- **WHEN** a user re-uploads a file with one of these five elements under a different extension
- **THEN** the file does not reach a more permissive ruleset
- **AND** each of the five elements is valid in SVG and none executes script on its own

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

Every requirement in this capability SHALL apply to any upload a browser parses as markup, not only to files named `.svg`. The rejection rules are the same for an HTML, XHTML, XML or XSL upload as for an SVG. `upload-content-security` specifies which uploads reach this checker.

#### Scenario: The same rules apply to every markup format
- **WHEN** an HTML, XHTML, XML or XSL upload has a script element, an `on` attribute, a blocked URI scheme, or entity-expanded content
- **THEN** the checker reports it unsafe
- **AND** the same holds for the elements `form`, `meta`, `base`, `style`, `link`, `foreignObject`, `handler`, `iframe`, `object` and `embed`

#### Scenario: An XHTML upload carrying a script element is rejected
- **WHEN** an `.xhtml` upload contains a `<script>` element
- **THEN** the checker reports it unsafe and the upload is not stored

#### Scenario: An XML upload carrying a blocked scheme is rejected
- **WHEN** an `.xml` upload contains an `href` attribute with a `javascript:` URI
- **THEN** the checker reports it unsafe and the upload is not stored

#### Scenario: Clean markup is accepted
- **WHEN** an `.html` upload contains ordinary formatting markup with no handlers, script, blocked elements or blocked schemes
- **THEN** the checker reports it safe and the upload is stored normally

### Requirement: Event handlers are rejected by shape

The checker SHALL reject event handlers by shape: any attribute whose name begins with `on`, case-insensitively. It SHALL NOT decide event handlers by matching a list of known handler names. Such a list is unbounded and grows with the web platform.

#### Scenario: An HTML upload with an unlisted handler is rejected
- **WHEN** an `.html` upload contains an `onpointerdown` attribute
- **THEN** the checker reports it unsafe and the upload is not stored

#### Scenario: A future handler name needs no rule change
- **WHEN** an `.html` upload contains an attribute named `onsomethingnotyetinvented`
- **THEN** the checker reports it unsafe, because the match is on the `on` prefix and not on a name list

### Requirement: HTML-family markup is evaluated with an HTML parser

The system SHALL parse `html`, `htm` and `shtml` uploads with an HTML parser rather than an XML parser. The XML parser SHALL remain in use for `svg`, `svgz`, `xhtml`, `xht`, `xml`, `xsl` and `xslt`.

#### Scenario: A structurally ordinary HTML document is not rejected merely for being HTML
- **WHEN** an `.html` upload contains unclosed `<p>` tags, an implicit `<tbody>`, or attribute values without quotes
- **THEN** the checker does not reject it for those reasons alone
- **AND** the reason is that an HTML document is not well-formed XML, so an XML parse rejects or misreads it

#### Scenario: HTML comments do not cause rejection
- **WHEN** an `.html` upload contains an ordinary HTML comment
- **THEN** the checker does not reject it for the comment

### Requirement: Both parse modes apply the same rejection rules

Both parse modes SHALL apply the same rejection rules, so the verdict for a given payload does not depend on which parser read it. The element check SHALL fold case.

#### Scenario: The same payload gets the same verdict in either mode
- **WHEN** identical event-handler markup is scanned once as `.html` and once as `.xhtml`
- **THEN** both are reported unsafe

#### Scenario: A camelCase blocked element is rejected in HTML mode too
- **WHEN** markup carrying a `<foreignObject>` element is scanned once as `.svg` (XML mode) and once as `.html` (HTML mode, where the parser lowercases it to `foreignobject`)
- **THEN** both are reported unsafe, because the element check folds case
- **AND** a case-sensitive match refuses the construct in XML mode but accepts it in HTML mode

#### Scenario: An uppercase script element is rejected
- **WHEN** an upload contains `<SCRIPT>`
- **THEN** the checker reports it unsafe
- **AND** the reason is that an SVG inlined into an HTML document fires `<SCRIPT>` exactly as `<script>`
