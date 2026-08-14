# draft-authorization

## ADDED Requirements

### Requirement: Draft custom-field options are confined to registered slugs

`Posts::DraftsController#create` and `#update` SHALL filter `field_options` through the post type's
registered-slug allow-list (`cama_permitted_field_options('PostType_Post')`) before persisting them,
exactly as the main post save does. A `field_options` entry whose slug is not a registered custom
field of the post type SHALL be dropped rather than written as a `custom_field_value`, so a
hand-crafted payload cannot introduce rows with attacker-chosen slugs, ids or group numbers.

#### Scenario: An unregistered slug is dropped

- **WHEN** a draft create or update submits `field_options` carrying a registered slug and a slug
  not registered on the post type
- **THEN** the registered slug's value is stored and the unregistered slug is not written

#### Scenario: Registered fields still persist

- **WHEN** a draft submits `field_options` for the post type's registered fields
- **THEN** those values are stored as before
