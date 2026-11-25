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
