# custom-field-group-tenancy Specification

## Purpose

Keep a custom field group's tenancy and its placement in agreement across site boundaries. A group's owning site is `parent_id`; the record whose admin page displays it is `object_class` + `objectid`. Because placement reads resolve without a site filter, a group whose two disagree renders on a site that does not own it while staying invisible in that site's own field-group list — so its administrators can neither find nor remove it.

Defines what placements a submission may claim, validated against what the current site actually owns, and how groups already violating the invariant are repaired. Complements [`custom-field-group-placement`](../custom-field-group-placement/spec.md), which covers which groups a given owner renders.

## Requirements
### Requirement: A submitted placement must target a record owned by the current site

When a custom field group is created or updated through the admin panel, the system SHALL verify that the submitted `assign_group` placement identifies a record belonging to the current site, and SHALL reject the submission otherwise.

Validation applies per placement class:

- `PostType`, `PostType_Post`, `PostType_Category`, `PostType_PostTag` — the id MUST belong to a post type of the current site.
- `Theme` — the id MUST belong to a theme of the current site.
- `NavMenu` — the id MUST belong to a nav menu of the current site.
- `Plugin` — the id MUST belong to a plugin of the current site.
- `Post` — the id MUST belong to a post of the current site.
- `Category`, `Category_Post` — the id MUST belong to a category of the current site.
- Any other class, including `Site`, the configured user model, and models registered through the `custom_field_custom_models` hook — the id MUST equal the current site's id.

#### Scenario: A placement targeting another site's post type is rejected

- **WHEN** a user who can manage custom fields on site A submits a field group with `assign_group` of `PostType_Post,<id of a post type owned by site B>`
- **THEN** no field group is persisted
- **AND** the response re-renders the form with an error
- **AND** site B's post type returns no additional field groups

#### Scenario: A placement targeting another site's theme is rejected

- **WHEN** a user who can manage custom fields on site A submits a field group with `assign_group` of `Theme,<id of a theme owned by site B>`
- **THEN** no field group is persisted
- **AND** site B's theme returns no additional field groups

#### Scenario: A placement targeting another site's nav menu is rejected

- **WHEN** a user who can manage custom fields on site A submits a field group with `assign_group` of `NavMenu,<id of a nav menu owned by site B>`
- **THEN** no field group is persisted
- **AND** site B's nav menu returns no additional field groups

#### Scenario: A single-target placement carrying another site's id is pinned, not rejected

`Site` is the one placement class with exactly one legal target, so a crafted id is replaced rather than refused. The coercion cannot attach the group to a record the submitter did not choose, and it is the behaviour already shipped.

- **WHEN** a user who can manage custom fields on site A submits a field group with `assign_group` of `Site,<site B id>`
- **THEN** the group is persisted with `objectid` equal to site A's id
- **AND** site B's `get_field_groups` excludes it

#### Scenario: An update cannot move a group onto another site

- **WHEN** an existing field group owned by site A is updated with `assign_group` naming a record owned by site B
- **THEN** the group's placement is unchanged
- **AND** the response re-renders the form with an error

#### Scenario: A placement targeting another site's plugin is rejected

- **WHEN** a user who can manage custom fields on site A submits a field group with `assign_group` of `Plugin,<id of a plugin owned by site B>`
- **THEN** no field group is persisted
- **AND** site B's plugin returns no additional field groups

#### Scenario: A valid placement is accepted

- **WHEN** a user who can manage custom fields on site A submits a field group naming a post type, theme, or nav menu owned by site A
- **THEN** the group is persisted with that placement
- **AND** it is returned by that record's `get_field_groups`

#### Scenario: A single-target class with the current site's id is accepted

- **WHEN** a field group is submitted with the configured user model or a class registered through the `custom_field_custom_models` hook, with the current site's id
- **THEN** the group is persisted with that placement

#### Scenario: A group whose stored placement is not offered by the form can still be re-saved

- **WHEN** an administrator edits a group whose stored `object_class` has no option in the placement select
- **AND** submits it with any target the current site owns
- **THEN** the group is persisted with the newly chosen placement

#### Scenario: A malformed placement is rejected

- **WHEN** a field group is submitted with an `assign_group` that is empty, has no id component, or names an id that does not exist
- **THEN** no field group is persisted
- **AND** the response re-renders the form with an error

### Requirement: Existing cross-site groups are re-homed to the site they render on

Custom field groups whose placement target belongs to a site other than the group's `parent_id` SHALL have `parent_id` set to the site owning the placement target, so the group becomes visible and removable in the admin field-group list of the site whose pages render it.

Groups SHALL NOT be deleted by this repair, and groups whose placement target no longer exists SHALL be left unchanged.

#### Scenario: An injected group becomes visible to the affected site

- **WHEN** a field group has `parent_id` of site A and a placement naming a theme owned by site B
- **AND** the repair task runs
- **THEN** the group's `parent_id` is site B's id
- **AND** the group appears in site B's field-group list
- **AND** the group no longer appears in site A's field-group list

#### Scenario: Correctly owned groups are untouched

- **WHEN** a field group's `parent_id` already matches the site owning its placement target
- **AND** the repair task runs
- **THEN** its `parent_id` is unchanged

#### Scenario: A group with a dangling placement target is left alone

- **WHEN** a field group's placement names an id that no longer exists
- **AND** the repair task runs
- **THEN** the group is neither deleted nor re-homed

