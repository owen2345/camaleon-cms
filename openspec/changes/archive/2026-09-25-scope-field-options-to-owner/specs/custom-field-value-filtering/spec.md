## ADDED Requirements

### Requirement: An admin custom-field save stores only the fields its form offers

Every admin save of custom-field values — site settings, theme settings (both payloads), post type,
post and draft, category, post tag, user, widget assignment and nav menu item — SHALL accept only
slugs of fields in the groups the corresponding form renders for the record being saved. A slug
registered only on another record of the same placement class (another post type, another site's
settings, theme or user groups, another widget, another menu) MUST NOT create a value row on the
record being saved. A slug registered on the record's own groups MUST save and read back as before.

#### Scenario: A sibling post type's slug is dropped from a post type save

- **WHEN** a field is registered on post type B and a save of post type A submits that slug
- **THEN** no value row is stored on post type A

#### Scenario: A sibling post type's slug is dropped from a post, draft, category or post tag save

- **WHEN** a field is registered for the posts, categories or tags of post type B and a save of a
  post, a draft, a category or a tag of post type A submits that slug
- **THEN** no value row is stored on the saved record

#### Scenario: Another site's slug is dropped from the site, theme and user saves

- **WHEN** a field is registered on site B's settings, theme or user groups and a save on site A
  submits that slug
- **THEN** no value row is stored on site A's record

#### Scenario: Another widget's slug is dropped from a widget assignment save

- **WHEN** a field is registered on widget B and a save of an assignment of widget A submits that slug
- **THEN** no value row is stored on the assignment

#### Scenario: A slug registered on the record saves

- **WHEN** a save submits a slug registered on the saved record's own groups, alongside a sibling
  record's slug
- **THEN** the registered slug's value is stored and readable back, and the sibling slug is dropped

### Requirement: A nav menu item save accepts the groups placed on its menu

A group placed on a nav menu through the custom-fields form (placement class `NavMenu`, the menu's
id) is what the menu item's custom-settings form renders. The menu item save SHALL accept the slugs
of that menu's groups and MUST NOT accept a slug registered only on another menu. The options of an
external menu item SHALL be permitted against the same set.

#### Scenario: A value for a field placed on the item's menu is stored

- **WHEN** a group is placed on the menu as the custom-fields form does and the item save submits a
  value for one of its fields
- **THEN** the value is stored and readable back from the item

#### Scenario: A slug registered on another menu is dropped

- **WHEN** the item save submits a slug registered only on a group placed on another menu
- **THEN** no value row is stored on the item

### Requirement: The shared permit keeps its class-wide default for callers that name no groups

A caller of the shared allow-list that passes only a placement class, as released plugins do, SHALL
keep accepting every slug registered under that class, across records and sites. Confining the
permit to one record requires the caller to pass the field groups its form renders.

#### Scenario: A class-only caller accepts a sibling record's slug

- **WHEN** a caller permits a payload naming only the placement class and the payload carries a slug
  registered on another record of that class
- **THEN** the slug is permitted

#### Scenario: A caller passing its groups drops a sibling record's slug

- **WHEN** a caller permits the same payload and passes the field groups of its own record
- **THEN** the sibling record's slug is not permitted
