## Purpose

Pin who owns custom-field teardown when an owning object is destroyed — the placement hook, with
complete callback-driven teardown — and that owners without the hook do not bulk-delete
definition rows they cannot tear down properly.

## ADDED Requirements

### Requirement: Owner destroy tears down its field definitions completely

A model carrying the placement hook (`CustomFieldsRead`) SHALL, when destroyed, destroy its
attached custom-field groups **with callbacks**: the group rows, their fields, those fields'
option metas, and the owner's stored values are all removed — nothing is left orphaned. Bulk
row deletion (skipping callbacks) MUST NOT be part of this path.

#### Scenario: Post destroy reaps its individual group

- **WHEN** a post carrying an individual custom-field group (with a field holding option metas
  and a stored value) is destroyed
- **THEN** the group row, the field row, the field's option metas, and the post's stored values
  are all gone

#### Scenario: Post type destroy reaps its placement groups

- **WHEN** a post type with a field group for its posts (placement scope `PostType_Post`) is
  destroyed
- **THEN** that group and its fields are destroyed with it

### Requirement: Owners without the placement hook do not cascade definitions

A model carrying only the common relationships (no placement hook — e.g. post comments) SHALL
NOT delete custom-field definition rows when destroyed (2.9.2 behavior): without the hook there
is no callback-driven teardown, and bulk deletion would remove group rows while orphaning their
fields and option metas.

#### Scenario: Comment destroy leaves attached definitions

- **WHEN** a post comment carrying an attached custom-field group (with a field holding option
  metas) is destroyed
- **THEN** the group row, the field row, and the field's option metas still exist
