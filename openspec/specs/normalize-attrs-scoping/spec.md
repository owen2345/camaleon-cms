# normalize-attrs-scoping

## Purpose

Ensure `normalize_attrs` (which applies `ActionController::Base.helpers.sanitize`) is only applied to model fields that genuinely contain user-submitted rich HTML. Plain-text and structured-data fields SHALL rely on Rails ERB auto-escaping for XSS prevention, avoiding data loss from inappropriate sanitization (e.g., angle brackets in email addresses, names, or JSON-serialized values).

## Requirements

### Requirement: Plain-text model fields are not sanitized at storage time
The system SHALL NOT apply `normalize_attrs` (which calls `sanitize()`) to fields that contain plain text rather than user-submitted HTML. These fields SHALL rely on Rails ERB auto-escaping (`<%= %>`) at render time for XSS prevention. Angle-bracket content in these fields SHALL be preserved in the database.

#### Scenario: User's first name containing angle brackets is preserved
- **WHEN** a user's `first_name` is set to `"Alice <alice@example.com>"`
- **THEN** the persisted value SHALL be `"Alice <alice@example.com>"`
- **AND** the `<` and `>` characters SHALL NOT be stripped

#### Scenario: Site name with formatting characters is preserved
- **WHEN** a site's `name` is set to `"Site <beta>"`
- **THEN** the persisted value SHALL be `"Site <beta>"`
- **AND** rendering it with `<%= @site.name %>` SHALL display it as escaped text

### Requirement: Meta values are not sanitized at storage time
The system SHALL NOT apply `normalize_attrs` to `Meta#value`. The value column stores serialized data (JSON, strings, arrays) that is not HTML content. Sanitizing it causes data corruption when values contain angle brackets (e.g., email addresses, comparison operators).

#### Scenario: Email setting with display name is preserved through save cycle
- **WHEN** a site option `email_from` is set to `"My Name <myemail@domain.com>"`
- **AND** the option is saved via `Site#set_option('email_from', value)` which serializes to JSON in `Meta#value`
- **THEN** reading back `get_option('email_from')` SHALL return `"My Name <myemail@domain.com>"`
- **AND** the email address `myemail@domain.com` SHALL NOT be stripped

#### Scenario: Meta value with comparison operator is preserved
- **WHEN** a meta record's value is set to `"count < 10"`
- **THEN** the persisted value SHALL be `"count < 10"`
- **AND** the `< 10` portion SHALL NOT be stripped

### Requirement: Normalize attrs remains on genuinely rich-text fields
The system SHALL keep `normalize_attrs(:content)` on `PostComment` (unchanged) and SHALL add it to `Post` for `:content` (with role-based conditional behavior defined in the post-content-sanitization spec). Models that retain `normalize_attrs` on description fields SHALL continue to sanitize those fields.

#### Scenario: Post comment content is still sanitized
- **WHEN** a visitor submits a comment with `<script>alert(1)</script>text`
- **THEN** the persisted comment content SHALL NOT contain `<script>`
- **AND** the text `"text"` SHALL be preserved

### Requirement: Models affected by normalize_attrs removal are explicit
The following model attributes SHALL NOT have `normalize_attrs` applied after this change:

- `Meta#value`
- `User#first_name`, `User#last_name`, `User#username`
- `UserRole#name`
- `Site#name`
- `Category#name`
- `PostType#name`
- `PostTag#name`
- `Plugin#name`
- `Theme#name`
- `NavMenu#name`
- `NavMenuItem#name`
- `Widget::Main#name`
- `Widget::Sidebar#name`

Description fields (`:description`) on the above models SHALL retain `normalize_attrs` unchanged (they may legitimately contain user HTML content).

#### Scenario: All cleaned models store angle brackets without stripping
- **WHEN** any of the listed models has a name field set to a value containing `<` or `>` (e.g., `Widget::Main.name = "promo <featured>"`)
- **THEN** the persisted value SHALL contain the angle brackets unchanged
