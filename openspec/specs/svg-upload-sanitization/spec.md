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

The system SHALL judge an upload in an XML-parsed markup format as a browser reads it. In that
form, the value of an internal DTD entity replaces each reference to the entity. The rejection rules
SHALL apply to each element, attribute and attribute value of that expanded document. A character
reference in an entity value SHALL count as the character that it names. The system SHALL reject
such an upload when its expanded form has a fatal XML error.

#### Scenario: SVG with DTD entity containing script tag is rejected
- **WHEN** a user uploads an SVG file with `<!ENTITY x "<script>alert(1)</script>">` and `&x;` in the body
- **THEN** the system returns an error and does NOT store the file (entity is expanded during parsing, script element is detected)

#### Scenario: SVG with DTD entity containing javascript: is rejected
- **WHEN** a user uploads an SVG file with `<!ENTITY xlink "javascript:">` and `xlink:href="&xlink;alert(1)"`
- **THEN** the system returns an error and does NOT store the file (entity is expanded during parsing, javascript: URI is detected)

#### Scenario: A handler name with a character reference in an entity value is rejected
- **WHEN** a user uploads an SVG file with `<!ENTITY x "<image href='x' &#111;nerror='alert(1)'/>">` and `&x;` in the body
- **THEN** the system returns an error and does NOT store the file
- **AND** the same holds when `&#60;` gives the tag start of the entity value
- **AND** the same holds for the file under an `.xml`, `.xhtml` or `.xsl` name

#### Scenario: A banned element in an entity value is rejected
- **WHEN** a user uploads an SVG file whose entity value holds a `foreignObject` element, and the body refers to the entity
- **THEN** the system returns an error and does NOT store the file
- **AND** the same holds for an entity value that holds `<&#115;cript>`

#### Scenario: An entity that the body reaches through another declaration is rejected
- **WHEN** a user uploads an SVG file whose body refers to an entity `a` with the value `&b;`
- **AND** the value of `b` holds an element with a handler
- **THEN** the system returns an error and does NOT store the file
- **AND** the same holds when a parameter entity declares the entity that holds the handler

#### Scenario: A scheme that an entity completes outside of an href is rejected
- **WHEN** a user uploads an SVG file with `<!ENTITY a "java">` and `<set attributeName="href" to="&a;script:alert(1)"/>`
- **THEN** the system returns an error and does NOT store the file

#### Scenario: A file with an entity declaration and a fatal XML error is rejected
- **WHEN** a user uploads an SVG file with `<!DOCTYPE svg [<!ENTITY x "hello">]>` and `&x;&missing;` in the body
- **THEN** the system returns an error and does NOT store the file

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
mode; HTML-parsed uploads are decided by the rejection rules and by the HTML5 requirement below.

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

#### Scenario: A fatal XML error in a file with a root element is rejected
- **WHEN** a user uploads an SVG file whose `g` element has no end tag
- **THEN** the system returns an error and does NOT store the file
- **AND** the same holds for the file under an `.xml`, `.xhtml` or `.xsl` name
- **AND** the same holds for text after the root element, and for an attribute that an element has two times

#### Scenario: An entity that the file does not declare is rejected
- **WHEN** a user uploads an SVG file with no DOCTYPE and `&nbsp;` in its body
- **THEN** the system returns an error and does NOT store the file

#### Scenario: An error that is not fatal does not reject the file
- **WHEN** a user uploads an SVG file with an `xlink:href` attribute and no declaration of the `xlink` prefix
- **THEN** the rejection rules decide, and the parse error alone does not reject the file

#### Scenario: An XHTML file that uses an entity of its public DTD is accepted
- **WHEN** a user uploads an `.xhtml` file with the public XHTML 1.0 DOCTYPE and `&nbsp;` in its body
- **THEN** the system stores the file normally

### Requirement: The parse-based checker governs every markup format, not only SVG

Every requirement in this capability SHALL apply to any upload a browser parses as markup, not only to files named `.svg`. The rejection rules are the same for an HTML, XHTML, XML or XSL upload as for an SVG. `upload-content-security` specifies which uploads reach this checker.

#### Scenario: The same rules apply to every markup format
- **WHEN** an HTML, XHTML, XML or XSL upload has a script element, an `on` attribute or a blocked URI scheme
- **THEN** the checker reports it unsafe
- **AND** the same holds for the elements `form`, `meta`, `base`, `style`, `link`, `foreignObject`, `handler`, `iframe`, `object` and `embed`
- **AND** the rule for content that a DTD entity expands to is the rule of "Reject SVGs with DTD entities containing dangerous content"

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

### Requirement: An entity of another resource is refused

The system SHALL reject an upload in an XML-parsed markup format whose DTD declares an entity that
points to another resource, with `SYSTEM` or `PUBLIC`. This holds for a general entity, a parameter
entity and an unparsed entity, used or not. The scan cannot read the content of that resource. The
system MUST NOT open the resource that such an entity names.

#### Scenario: A general entity with SYSTEM is rejected
- **WHEN** a user uploads an SVG file with `<!ENTITY x SYSTEM "other.txt">`
- **THEN** the system returns an error and does NOT store the file

#### Scenario: A parameter entity with SYSTEM is rejected
- **WHEN** a user uploads an SVG file with `<!ENTITY % p SYSTEM "other.dtd">`
- **THEN** the system returns an error and does NOT store the file

#### Scenario: The scan does not open a local file
- **WHEN** a user uploads an SVG file with `<!ENTITY x SYSTEM "file:///etc/hosts">` and `&x;` in the body
- **THEN** the system returns an error
- **AND** the scan does not expand the entities of that file

### Requirement: The entity expansion has a limit

The system SHALL reject an upload in an XML-parsed markup format whose entities expand past the
limit of the XML parser. It SHALL reject an upload whose entity refers to itself, directly or
through another entity. The scan MUST stop at the limit of the parser, so that it does not hold the
expanded text in memory.

#### Scenario: Nested entities that expand to a billion characters are rejected
- **WHEN** a user uploads an SVG file with an entity of ten characters and eight more entities
- **AND** each of the eight refers ten times to the entity before it
- **THEN** the system returns an error and does NOT store the file

#### Scenario: One large entity with many references is rejected
- **WHEN** a user uploads an SVG file with an entity of 100,000 characters and 20,000 references to it
- **THEN** the system returns an error and does NOT store the file

#### Scenario: An entity that refers to itself is rejected
- **WHEN** a user uploads an SVG file in which entity `a` holds `&b;` and entity `b` holds `&a;`
- **THEN** the system returns an error and does NOT store the file
- **AND** the same holds for an SVG file in which entity `a` holds `&a;`

### Requirement: A file with harmless entities is accepted

The system SHALL accept an upload in an XML-parsed markup format that declares internal DTD
entities, when its expanded form breaks no rejection rule.

#### Scenario: An entity that expands to text is accepted
- **WHEN** a user uploads an SVG file with `<!ENTITY x "hello">` and `&x;` in a `desc` element
- **THEN** the system stores the file normally

#### Scenario: An entity that expands to a shape is accepted
- **WHEN** a user uploads an SVG file with `<!ENTITY x "<rect width='10' height='10'/>">` and `&x;` in the body
- **THEN** the system stores the file normally

#### Scenario: The namespace entities of Adobe Illustrator are accepted
- **WHEN** a user uploads an SVG file with a public SVG 1.1 DOCTYPE and `<!ENTITY ns_ai "http://ns.adobe.com/AdobeIllustrator/10.0/">`
- **AND** an element declares a namespace with `xmlns:i="&ns_ai;"`
- **THEN** the system stores the file normally

#### Scenario: An entity whose text shows escaped markup is accepted
- **WHEN** a user uploads an SVG file with `<!ENTITY x "&lt;script&gt;">` and `&x;` in a `desc` element
- **THEN** the system stores the file normally, because the browser shows that value as text

#### Scenario: An entity that the file does not use is accepted
- **WHEN** a user uploads an SVG file with `<!ENTITY x "hello">` and no reference to it
- **THEN** the system stores the file normally

### Requirement: An attribute default of the DTD follows the attribute rules

A browser gives an element each attribute default that the DTD of the file declares for it. In an
XML-parsed markup format, the system SHALL reject an upload whose DTD declares a default for a
handler attribute. A handler attribute has a name that starts with `on`, in any case. The system
SHALL reject a default that holds a blocked URI scheme, also when an entity gives a part of the
scheme. A declaration without a default gives no attribute, and the system SHALL accept it.

#### Scenario: A default for a handler attribute is rejected
- **WHEN** a user uploads an SVG file with `<!ATTLIST svg onload CDATA "alert(1)">`
- **THEN** the system returns an error and does NOT store the file
- **AND** the same holds for the file under an `.xml`, `.xhtml` or `.xsl` name
- **AND** the same holds for a `#FIXED` default, an enumerated type and the name `ONLOAD`

#### Scenario: A default with a scheme that an entity completes is rejected
- **WHEN** a user uploads an SVG file with `<!ENTITY j "java">` and `<!ATTLIST a href CDATA "&j;script:alert(1)">`
- **THEN** the system returns an error and does NOT store the file

#### Scenario: A default that a parameter entity declares is rejected
- **WHEN** a user uploads an SVG file whose parameter entity holds `<!ATTLIST svg onload CDATA 'alert(1)'>`
- **AND** the DTD refers to that parameter entity
- **THEN** the system returns an error and does NOT store the file

#### Scenario: A harmless declaration is accepted
- **WHEN** a user uploads an SVG file with `<!ATTLIST svg xmlns:xlink CDATA #FIXED "http://www.w3.org/1999/xlink">`
- **THEN** the system stores the file normally
- **AND** the same holds for `<!ATTLIST svg onload CDATA #IMPLIED>`, which has no default
- **AND** the same holds for `<!ATTLIST svg xmlns:onix CDATA #FIXED "urn:onix">`, which declares a namespace

### Requirement: A default that the scan cannot read is refused

The XML parser of the scan keeps no default for a declaration whose default does not fit the type
of the attribute. It keeps only the first declaration of an attribute. A browser uses the default
in both cases. The system SHALL reject an upload whose DTD declares an attribute when the parser
reports one of the two cases. It SHALL also reject such an upload when the parser reaches its
limit of 100 reports.

#### Scenario: A default that does not fit the type of the attribute is rejected
- **WHEN** a user uploads an SVG file with `<!ATTLIST svg onload NMTOKEN "alert(1)">`
- **THEN** the system returns an error and does NOT store the file
- **AND** the same holds for `<!ATTLIST svg onload (a|b) "alert(1)">`

#### Scenario: A second declaration of an attribute is rejected
- **WHEN** a user uploads an SVG file with `<!ATTLIST svg onload CDATA #IMPLIED>` and then `<!ATTLIST svg onload CDATA "alert(1)">`
- **THEN** the system returns an error and does NOT store the file
- **AND** the same holds when a parameter entity gives the second declaration

#### Scenario: The parser reaches its report limit before the declaration
- **WHEN** a user uploads an SVG file with 100 references to an undeclared parameter entity, and then the two declarations of `onload`
- **THEN** the system returns an error and does NOT store the file

#### Scenario: A default that fits its type follows the attribute rules
- **WHEN** a user uploads an SVG file with `<!ATTLIST rect fill NMTOKEN "red">`
- **THEN** the system stores the file normally

### Requirement: A stylesheet instruction is rejected

The system SHALL reject a markup upload that holds an `xml-stylesheet` processing instruction, for
any stylesheet type. In an XML-parsed format, the rule SHALL hold for an instruction at any place
in the document and in the DTD. In an HTML-parsed format, the rule SHALL hold for each instruction
that the HTML parser keeps as a node. The instruction loads a CSS or an XSL stylesheet, as the
rejected `link` and `style` elements do.

#### Scenario: An instruction for a CSS file is rejected
- **WHEN** a user uploads an SVG file with `<?xml-stylesheet type="text/css" href="https://evil.example/x.css"?>` before the root element
- **THEN** the system returns an error and does NOT store the file
- **AND** the same holds for the file under an `.xml` or `.xhtml` name
- **AND** the same holds for an instruction in an element, and for an instruction in the DTD of the file

#### Scenario: An instruction for an XSL file is rejected
- **WHEN** a user uploads an `.xml` file with `<?xml-stylesheet type="text/xsl" href="x.xsl"?>`
- **THEN** the system returns an error and does NOT store the file

#### Scenario: An instruction in an HTML file is rejected
- **WHEN** a user uploads an `.html` file with `<?xml-stylesheet href="x.css"?>` before the `html` element
- **THEN** the system returns an error and does NOT store the file

#### Scenario: Another processing instruction is accepted
- **WHEN** a user uploads an SVG file with `<?editor version="2"?>` and no rejected content
- **THEN** the system stores the file normally

### Requirement: A file that declares the XSLT namespace is rejected

The system SHALL reject an upload in an XML-parsed markup format that declares the namespace
`http://www.w3.org/1999/XSL/Transform`, used or not. An XSLT stylesheet is a program. It can build
the name of an element or of an attribute when it runs, so the scan cannot judge its result. The
rule SHALL hold when an entity or an attribute default of the DTD gives the namespace. It SHALL
hold when a named reference gives a character of the namespace.

#### Scenario: A stylesheet that builds a handler name is rejected
- **WHEN** a user uploads an `.xsl` file whose `html` root element has an `xsl:version` attribute and no `xsl:template`
- **AND** the file builds an attribute with `xsl:attribute name="{concat('o','nerror')}"`
- **THEN** the system returns an error and does NOT store the file
- **AND** the same holds for the file under an `.xslt`, `.xml` or `.xhtml` name

#### Scenario: A namespace from an entity or an attribute default is rejected
- **WHEN** a user uploads a file whose entity holds the XSLT namespace URI, and an `xmlns` attribute refers to the entity
- **THEN** the system returns an error and does NOT store the file
- **AND** the same holds when an `ATTLIST` declaration gives the `xmlns:xsl` attribute as a default

#### Scenario: A namespace with a named reference is rejected
- **WHEN** a user uploads an `.xsl` file with the public XHTML 1.0 Strict DOCTYPE and `xmlns:xsl="http:&sol;/www.w3.org/1999/XSL/Transform"`
- **THEN** the system returns an error and does NOT store the file
- **AND** the same holds when `&colon;` or `&period;` gives a character of the namespace

#### Scenario: A declaration that no element uses is rejected
- **WHEN** a user uploads an SVG file whose root element declares the XSLT namespace, and no element uses it
- **THEN** the system returns an error and does NOT store the file

#### Scenario: Another namespace, and text that names the XSLT namespace, are accepted
- **WHEN** a user uploads an SVG file that declares the `xlink` namespace
- **THEN** the system stores the file normally
- **AND** the same holds for an SVG file whose `desc` element holds the XSLT namespace URI as text

### Requirement: A dropped scheme reference in a file with entities is rejected

In an XML file with a public XHTML DOCTYPE, a browser reads an HTML name such as `&colon;` that
the file does not declare. The XML parser of the scan drops that reference. The system SHALL
reject an upload that declares a DTD entity and has a dropped reference to one of the eight names
of the normalization. The system SHALL also reject an upload that declares a DTD entity when the
parser reaches its limit of 100 reports.

#### Scenario: An entity gives a part of the scheme, and a name gives its colon
- **WHEN** a user uploads an `.xhtml` file with the public XHTML 1.0 Strict DOCTYPE, `<!ENTITY a "java">` and `<a href="&a;script&colon;alert(1)">`
- **THEN** the system returns an error and does NOT store the file
- **AND** the same holds for `<!ENTITY c "&#38;colon;">` with `<a href="javascript&c;alert(1)">`
- **AND** the same holds for the first link in an `.svg` file with that DOCTYPE and that entity

#### Scenario: The parser reaches its report limit before the name
- **WHEN** a user uploads an `.xhtml` file with the public XHTML 1.0 Strict DOCTYPE, `<!ENTITY a "java">`, 100 `&nbsp;` references and then `<a href="&a;script&colon;alert(1)">`
- **THEN** the system returns an error and does NOT store the file

#### Scenario: Another name that the file does not declare is accepted
- **WHEN** a user uploads an `.xhtml` file with the public XHTML 1.0 Strict DOCTYPE, `<!ENTITY a "text">` and `<p>&a; a&nbsp;b</p>`
- **THEN** the system stores the file normally

#### Scenario: A name that the file declares is accepted
- **WHEN** a user uploads an `.xhtml` file with the public XHTML 1.0 Strict DOCTYPE, `<!ENTITY colon ":">` and `<p>10&colon;30</p>`
- **THEN** the system stores the file normally

### Requirement: An HTML upload is judged as a browser parses it

The HTML parser of the scan follows HTML 4, and a browser follows the HTML5 rules. For an
HTML-parsed format, the system SHALL also build the tree of an HTML5 parser, with the content of a
`noscript` element as text. The rejection rules SHALL apply to both trees. The system SHALL reject
an upload that gives the HTML5 parser no tree, because the scan cannot judge it. For the same
reason, it SHALL reject an upload with a `noscript` element when that parser cannot read its
content as text.

#### Scenario: A handler after a comment start in a raw text element is rejected
- **WHEN** a user uploads an `.html` file with `<xmp><!--</xmp><img src=x onpointerdown=alert(1)>--></xmp>`
- **THEN** the system returns an error and does NOT store the file
- **AND** the same holds for a `title`, a `textarea` or a `noscript` element in place of `xmp`

#### Scenario: A charset in a tag that is not a meta element does not change the HTML5 tree
- **WHEN** a user uploads an `.html` file with `<metadata charset=IBM037></metadata>` before that `xmp` element
- **THEN** the system returns an error and does NOT store the file

#### Scenario: A handler name in a comment is accepted
- **WHEN** a user uploads an `.html` file with `<!-- <img src=x onpointerdown=alert(1)> -->` and no rejected content
- **THEN** the system stores the file normally

#### Scenario: A file past the nesting limit of the HTML5 parser is rejected
- **WHEN** a user uploads an `.html` file with 500 nested `div` elements
- **THEN** the system returns an error and does NOT store the file

#### Scenario: A file that the HTML5 parser cannot read is rejected
- **WHEN** a user uploads an `.html` file in UTF-16 that ends with half of a character
- **THEN** the system returns an error and does NOT store the file

### Requirement: A select element of an HTML upload is rejected

Chrome 158 keeps most elements in a `select` element. The HTML5 parser of the scan drops most
elements there, such as `xmp` and `img`, and it does not read the content of a dropped `xmp`
element as text. So neither tree of the scan shows the page of the browser there. For an
HTML-parsed format, the system SHALL reject an upload with a `select` element.

#### Scenario: A comment start in a select element is rejected
- **WHEN** a user uploads an `.html` file with `<select><xmp><!--</xmp><img src=x onpointerdown=alert(1)>--></xmp></select>`
- **THEN** the system returns an error and does NOT store the file

#### Scenario: An xmp end tag in an option attribute is rejected
- **WHEN** a user uploads an `.html` file with `<select><xmp><option title="</xmp><img src=x onpointerdown=alert(1)>"></option></xmp></select>`
- **THEN** the system returns an error and does NOT store the file

#### Scenario: A select element with only option elements is rejected
- **WHEN** a user uploads an `.html` file with a `select` element that holds only `option` elements
- **THEN** the system returns an error and does NOT store the file
