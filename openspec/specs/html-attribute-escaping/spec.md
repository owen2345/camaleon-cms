# html-attribute-escaping Specification

## Purpose
TBD - created by archiving change fix-contact-form-output-escaping. Update Purpose after archive.
## Requirements
### Requirement: `Hash#to_attr_format` escapes values for the HTML attribute context

`Hash#to_attr_format` SHALL escape each value for interpolation into a double-quoted HTML attribute, so that no value can terminate its own attribute or introduce a new one. The escaping SHALL target HTML, not a Ruby string literal.

The method is public API shipped in the gem and is called by plugins and themes packaged as separate gems, so it SHALL remain safe for callers that pass fully untrusted values without pre-escaping.

#### Scenario: Value containing a double quote cannot break out of the attribute
- **WHEN** `{ class: 'x" onfocus=alert(1) y="' }.to_attr_format` is rendered into `<input …>`
- **THEN** the output SHALL NOT contain an unescaped `"` inside the attribute value
- **AND** the resulting element SHALL have exactly one attribute, `class`
- **AND** the resulting element SHALL NOT have an `onfocus` attribute

#### Scenario: Backslash-quote sequences are not treated as escapes
- **WHEN** a value contains the literal two-character sequence `\"`
- **THEN** the output SHALL escape the `"` for HTML rather than relying on the preceding backslash
- **AND** parsing the result SHALL yield the original value including its backslash

#### Scenario: Angle brackets in a value cannot open a tag
- **WHEN** a value contains `</textarea><script>alert(1)</script>`
- **THEN** the output SHALL NOT contain a parseable `<script>` start tag
- **AND** the value SHALL round-trip as text when the attribute is read back

#### Scenario: Ordinary values are unchanged apart from escaping
- **WHEN** `{ id: 'field_3', 'data-role': 'input' }.to_attr_format` is called
- **THEN** the output SHALL contain both pairs with their values intact
- **AND** values containing no HTML-significant characters SHALL be byte-identical to the input

#### Scenario: Custom separator is preserved
- **WHEN** `to_attr_format` is called with a non-default separator argument
- **THEN** the pairs SHALL be joined with that separator, unchanged from current behavior

### Requirement: `Hash#to_attr_url_format` emits a well-formed Ruby string literal

`Hash#to_attr_url_format` emits a Ruby-style `:key => "value"` fragment for code generation, not HTML. Every emitted value SHALL be a complete, correctly escaped double-quoted Ruby literal, such that any input round-trips unchanged through evaluation.

It SHALL NOT be given the HTML escaper used by `to_attr_format`: its output is not HTML, and entity-encoding would corrupt the generated code.

This is a correctness requirement, not a security one. The method's existing quote handling is already correct for its context — `'a"b'` round-trips today. What it misses is the backslash, which is itself an escape character inside a double-quoted literal.

#### Scenario: Value containing a double quote round-trips
- **WHEN** a value containing `"` is passed to `to_attr_url_format`
- **THEN** evaluating the emitted fragment SHALL yield the original value

#### Scenario: Literal backslash is preserved rather than forming an escape sequence
- **WHEN** a value contains a backslash, as in `a\b`
- **THEN** evaluating the emitted fragment SHALL yield that value unchanged
- **AND** SHALL NOT yield a control character

#### Scenario: Backslash immediately preceding a quote does not break the literal
- **WHEN** a value contains `a\"b`
- **THEN** the emitted fragment SHALL be syntactically valid Ruby
- **AND** evaluating it SHALL yield the original value

#### Scenario: HTML entities are not introduced
- **WHEN** a value contains `<` or `&`
- **THEN** the emitted fragment SHALL contain those characters literally
- **AND** SHALL NOT contain `&lt;` or `&amp;`

