## ADDED Requirements

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

## MODIFIED Requirements

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
