## ADDED Requirements

### Requirement: An unchanged custom field value is not checked again

The gate SHALL NOT check a custom field value that `set_field_values` creates again with the same
slug and value as a stored row. The admin form of a post sends each stored value again on each
save. A value that changes SHALL be checked as before.

#### Scenario: A title change keeps the shortcode of an administrator

- **WHEN** a custom field of a post holds a shortcode that an administrator saved
- **AND** an editor without `content_shortcodes` changes only the title of the post
- **THEN** the save SHALL succeed, and the field SHALL keep the shortcode

#### Scenario: A changed shortcode value is still refused

- **WHEN** the same editor adds a shortcode to that field value
- **THEN** the save SHALL be refused, and nothing SHALL be stored
