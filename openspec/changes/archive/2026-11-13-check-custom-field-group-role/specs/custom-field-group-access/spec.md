## Purpose

A user needs the `custom_fields` permission to read or change a custom field group in the admin
panel. The capability gives the actions of the custom fields controller that check this permission.

## ADDED Requirements

### Requirement: The custom field group pages check the custom_fields permission

Each action of `Admin::Settings::CustomFieldsController` SHALL require the `custom_fields`
permission, except the `list` action. A request of a user with no such permission SHALL get a
redirect to the dashboard, and MUST NOT change or show a field group. The `list` action SHALL keep
its own check of the right of the user on the post or on the post type.

#### Scenario: A user with no permission sends a new order

- **WHEN** a user with no `custom_fields` permission sends `POST /admin/settings/custom_fields/reorder`
  with the ids of the field groups
- **THEN** the response is a redirect to the dashboard
- **AND** the order of the field groups stays as it was

#### Scenario: A user with no permission opens a page of the field groups

- **WHEN** a user with no `custom_fields` permission requests the list, a form, the page of a group
  or the settings of a field kind
- **THEN** the response is a redirect to the dashboard

#### Scenario: A user with the permission sends a new order

- **WHEN** a user with the `custom_fields` permission sends `POST /admin/settings/custom_fields/reorder`
  with the ids of the field groups
- **THEN** the field groups have the new order

#### Scenario: A user with the permission opens the form of a group

- **WHEN** a user with the `custom_fields` permission requests the form of a field group
- **THEN** the response is the form

#### Scenario: A user with no permission requests the fields of a new post

- **WHEN** a user with no `custom_fields` permission, who can create posts of a post type, requests
  `GET /admin/settings/custom_fields/list` for that post type
- **THEN** the response is the list of the fields of a new post

### Requirement: The Settings menu shows the Custom Fields item to a user with the custom_fields permission

The Settings menu of the admin panel SHALL show its Custom Fields item only to a user with the
`custom_fields` permission.

#### Scenario: A user with the settings permission and no custom_fields permission

- **WHEN** a user with the `settings` permission and no `custom_fields` permission opens an admin page
- **THEN** the Settings menu holds no Custom Fields item

#### Scenario: A user with the settings permission and the custom_fields permission

- **WHEN** a user with the `settings` permission and the `custom_fields` permission opens an admin
  page
- **THEN** the Settings menu holds the Custom Fields item
