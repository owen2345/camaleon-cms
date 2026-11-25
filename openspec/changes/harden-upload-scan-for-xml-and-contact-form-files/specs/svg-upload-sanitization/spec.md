## MODIFIED Requirements

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

## ADDED Requirements

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
