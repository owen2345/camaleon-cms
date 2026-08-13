# custom-field-value-rejection (delta)

## ADDED Requirements

### Requirement: Field-attribute values are gated on their decoded members and rendered verbatim

For `field_attrs` values — stored as a JSON pair whose members the frontend emits as markup — the
system SHALL parse the stored JSON and apply the markup gate to each **decoded** member, so that
markup hidden by JSON unicode-escaping (\u003c stored instead of a literal `<`) is refused exactly like literal markup;
a value that does not parse SHALL be scanned as stored. Trust, fail-closed and opt-out semantics
SHALL be those of the custom-field gate. The renderer SHALL emit the stored attribute name and
value verbatim, and SHALL emit the pair's value (not the attribute name twice).

#### Scenario: Script in a pair member is refused regardless of byte encoding

- **WHEN** an untrusted author saves a field_attrs pair whose value member carries a script
  element, whether the stored JSON holds it as literal bytes or unicode-escaped
- **THEN** the save is refused and no value row is stored

#### Scenario: Benign pairs are stored and rendered byte-for-byte

- **WHEN** an untrusted author saves a pair whose members stay within the markup allowlist
- **THEN** the pair is stored exactly as written and the frontend renders the attribute name and
  the value verbatim

#### Scenario: Trusted authors store any pair

- **WHEN** an admin (or a saver holding `post_content_unfiltered_html` for the post type) saves a
  pair carrying a script member
- **THEN** the pair is stored exactly as written

#### Scenario: The value member is rendered

- **WHEN** a stored pair `{attr: "Size", value: "XL"}` is rendered
- **THEN** the output shows `Size` as the label and `XL` as the value (not the label twice)
