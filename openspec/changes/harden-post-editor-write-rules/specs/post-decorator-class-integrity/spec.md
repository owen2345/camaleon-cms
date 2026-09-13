## MODIFIED Requirements

### Requirement: A post resolves its decorator safely

A post SHALL decorate with the class named by its post type's option when that class is a
`CamaleonCms::PostDecorator` subclass, and with `CamaleonCms::PostDecorator` otherwise: a blank
option, a post without a post type, a post type whose options row is not a JSON object (which reads as
no options), or a stored value the check would refuse (written before the check, left by a removed
plugin, or imported). A stored value that is ignored SHALL be logged as a warning naming the post type
and the value, once per request for each post type and value, and SHALL NOT be rewritten. A lookup
that fails SHALL be logged with the error.

#### Scenario: A stored value the check would refuse

- **WHEN** a post type's stored option names a class that is not a post decorator, or a name that
  cannot be loaded
- **THEN** its posts SHALL decorate with the default decorator, rendering SHALL succeed, one warning
  SHALL be logged per request, and the stored option SHALL be unchanged

#### Scenario: No post type

- **WHEN** a post has no post type
- **THEN** it SHALL decorate with the default decorator

#### Scenario: Options that cannot be read

- **WHEN** a post's post type has an options row that is not a JSON object
- **THEN** the post SHALL decorate with the default decorator without a lookup failure, and the row
  is reported by the scan task
