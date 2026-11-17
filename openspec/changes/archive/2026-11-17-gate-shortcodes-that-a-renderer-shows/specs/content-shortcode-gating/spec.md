## ADDED Requirements

### Requirement: The gate scans each text that a renderer expands

The gate SHALL scan each text that a renderer gives to `do_shortcode`, not only the stored text. These texts SHALL be the stored text and each translation of it. When a custom-field value parses as a JSON object, they SHALL also be the text of each member and each translation of that text. `the_json_field` gives these texts to `do_shortcode`. A save SHALL be gated when one of these texts contains a registered shortcode.

#### Scenario: A translation that joins a shortcode is gated

- **WHEN** a non-administrator without `content_shortcodes` saves post content, a taxonomy description or a custom-field value
- **AND** its stored text contains no registered shortcode, but a translation of it contains one
- **THEN** the save SHALL be rejected the same way as a stored shortcode

#### Scenario: A JSON member that shows a shortcode is gated

- **WHEN** a non-administrator without `content_shortcodes` saves a custom-field value whose stored text contains no registered shortcode
- **AND** the text of a member of its JSON object contains one
- **AND** a JSON escape of a bracket, or a member that is an object or an array, shows that shortcode
- **THEN** the save SHALL be rejected the same way as a stored shortcode

#### Scenario: A translated or JSON value with no shortcode is unaffected

- **WHEN** any user saves a translated value or a JSON value in which no text that a renderer expands contains a registered shortcode
- **THEN** the save SHALL NOT be gated by `content_shortcodes`
