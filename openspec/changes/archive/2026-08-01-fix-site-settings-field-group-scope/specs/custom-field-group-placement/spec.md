## ADDED Requirements

### Requirement: A site renders only the field groups placed on it

`CamaleonCms::Site#get_field_groups` SHALL return only custom field groups whose placement identifies that site — `object_class` equal to `Site` and `objectid` equal to the site's id — scoped to the groups the site owns via `parent_id`. Groups placed on other content types SHALL NOT be returned, regardless of which site owns them.

This applies to every read that flows through `get_field_groups`, including the "Custom Configurations" tab of `/admin/settings/site`.

#### Scenario: Site settings render site-placed fields

- **WHEN** a site owns a field group with `object_class: 'Site'` containing a field
- **THEN** `site.get_field_groups` includes that group
- **AND** the field is rendered on `/admin/settings/site`

#### Scenario: Site settings omit groups placed on other content types

- **WHEN** a site owns field groups placed on `PostType_Post`, `PostType_Category`, `PostType_PostTag`, `Theme`, `NavMenu`, or `User`
- **THEN** `site.get_field_groups` excludes every one of them
- **AND** none of their fields are rendered on `/admin/settings/site`

#### Scenario: A required field of another content type does not block saving site settings

- **WHEN** a site owns a field group placed on a post type that contains a field marked required
- **AND** an administrator submits the site settings form without supplying a value for that field
- **THEN** the submission succeeds and the site's own settings are persisted

#### Scenario: The Custom Configurations tab is hidden when the site has no groups of its own

- **WHEN** a site owns field groups but none of them is placed on the site
- **THEN** `/admin/settings/site` does not render the Custom Configurations tab

#### Scenario: A group owned by another site is not returned

- **WHEN** a field group has `object_class: 'Site'` and `objectid` equal to site A's id, but is owned by site B via `parent_id`
- **THEN** `site_a.get_field_groups` excludes it

### Requirement: Other owners keep their existing placement scope

Narrowing the site scope SHALL NOT change what any other owner returns from `get_field_groups`. Themes, plugins, nav menus, widgets, post types, posts, categories, and post tags continue to resolve their groups exactly as before.

#### Scenario: Theme settings are unchanged

- **WHEN** a site owns a `Theme` group and a `Site` group
- **THEN** `theme.get_field_groups` returns the `Theme` group and excludes the `Site` group

#### Scenario: Post type settings are unchanged

- **WHEN** a site owns a `PostType_Post` group and a `Site` group
- **THEN** `post_type.get_field_groups('Post')` returns the `PostType_Post` group and excludes the `Site` group

### Requirement: A site field group created for a site is stamped with its placement

`Site#add_custom_field_group` SHALL persist the new group with `object_class` set to `Site` and `objectid` set to the site's id, so the group is reachable from the site that created it.

#### Scenario: Programmatic creation succeeds and is readable back

- **WHEN** `site.add_custom_field_group({ name: 'Group', slug: '_group' })` is called
- **THEN** the group is persisted with `object_class: 'Site'` and `objectid` equal to the site's id
- **AND** `site.get_field_groups` includes it

### Requirement: Site field values resolve against the site's own fields

`Site#get_field_object` and `Site#set_field_value` SHALL resolve a field slug only among fields belonging to groups placed on that site, so a site-level value cannot bind to a field defined for a post, category, theme, or other content type.

#### Scenario: A slug shared with a foreign group resolves to the site's field

- **WHEN** a site owns a `Site` group and a `PostType_Post` group that each define a field with the same slug
- **AND** `site.set_field_value(<slug>, <value>)` is called
- **THEN** the stored value references the field belonging to the `Site` group

### Requirement: Site placement is pinned to the current site on submission

When an administrator submits a custom field group whose placement class is `Site`, the system SHALL record `objectid` as the current site's id, ignoring any submitted value. A crafted `assign_group` parameter SHALL NOT produce a `Site`-placed group carrying another site's id.

#### Scenario: A crafted objectid is replaced

- **WHEN** an administrator of site A submits a field group with `assign_group` of `Site,<site B id>`
- **THEN** the persisted group has `object_class: 'Site'` and `objectid` equal to site A's id
- **AND** `site_a.get_field_groups` includes it
- **AND** `site_b.get_field_groups` excludes it

### Requirement: Existing site groups without a placement id can be backfilled

A maintenance task SHALL set `objectid` from `parent_id` on custom field group rows with `object_class` of `Site` and a `NULL` `objectid`, so that groups created before this change become visible again under the placement-scoped read. The task SHALL report how many rows it updated and skipped, and SHALL NOT abort the run when a single row fails.

#### Scenario: A legacy group without objectid becomes visible

- **WHEN** a field group exists with `object_class: 'Site'`, `parent_id` of a site, and `objectid` of `NULL`
- **AND** the backfill task runs
- **THEN** the row's `objectid` equals its `parent_id`
- **AND** that site's `get_field_groups` includes the group

#### Scenario: Groups of other placement classes are untouched

- **WHEN** field groups exist with `object_class` other than `Site`, including rows with a `NULL` `objectid`
- **AND** the backfill task runs
- **THEN** their `objectid` values are unchanged

#### Scenario: A site group with no owning site is skipped

- **WHEN** a field group has `object_class: 'Site'` and both `objectid` and `parent_id` are `NULL`
- **AND** the backfill task runs
- **THEN** the row is left unchanged and counted as skipped

#### Scenario: One failing row does not stop the run

- **WHEN** the backfill task encounters a row it cannot update
- **THEN** it records the failure and continues with the remaining rows

### Requirement: Destroying a site still removes every group it owns

Narrowing what `get_field_groups` returns for a site SHALL NOT leave orphaned rows. Destroying a site SHALL remove every custom field group the site owns via `parent_id`, together with those groups' fields.

#### Scenario: All owned groups are removed on site destroy

- **WHEN** a site owns field groups placed on `Site`, on a post type, and on a theme
- **AND** the site is destroyed
- **THEN** none of those groups remain
- **AND** none of their fields remain
