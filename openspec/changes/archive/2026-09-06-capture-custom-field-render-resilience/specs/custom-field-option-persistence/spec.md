## Purpose

Saving a custom-field group replaces each field's whole option set with what the settings form
posts, so any offered option the save drops is lost for good and wiped from a previously saved
field on re-save. The capability pins which per-kind options a save keeps and the one it refuses.

## ADDED Requirements

### Requirement: Saving a field definition keeps its per-kind options

Saving a custom-field group SHALL persist, for each field, every per-kind extra option the
settings panels offer alongside the common options: the colorpicker's colour format, the date
field's date-versus-datetime type, the image field's dimension and versions, the file field's
formats, the posts field's post-type filter, and the panel's collapsed state. An offered option
MUST NOT be silently discarded on save.

#### Scenario: Every offered per-kind option is stored

- **WHEN** an admin saves a group holding a colorpicker with a colour format and a collapsed
  panel, an image field with a dimension and versions, a date field set to datetime, and a posts
  field with a post-type filter
- **THEN** each field's stored options include those values

### Requirement: The select_eval command is not accepted from the request

The save SHALL NOT accept the `select_eval` field's `command` option from the request, whatever
the settings form posts: the option holds a Ruby expression, and the field stays a deliberately
non-working capability. A submitted `command` SHALL be dropped without failing the save of the
other options.

#### Scenario: A submitted command is dropped

- **WHEN** an admin saves a field whose posted options include a `command`
- **THEN** the field's stored options do not include it and its other options are stored
