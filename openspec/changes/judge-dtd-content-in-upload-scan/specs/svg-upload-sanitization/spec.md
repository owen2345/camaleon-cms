## MODIFIED Requirements

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

## ADDED Requirements

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
