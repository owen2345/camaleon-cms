# runtime-compat-surfaces Specification

## Purpose
TBD - created by archiving change restore-runtime-compat-surfaces. Update Purpose after archive.
## Requirements
### Requirement: Legacy 2-argument taxonomy-list calls resolve the post type from the controller
`post_type_list_taxonomy` SHALL accept its legacy 2-argument form (`taxonomies`, `color`) and resolve
the post type from the controller's `@post_type` when the third argument is omitted, so overridden
admin posts-index views render taxonomy links rather than empty output.

#### Scenario: A 2-argument call renders the taxonomy links
- **WHEN** `post_type_list_taxonomy(taxonomies, 'primary')` is called while the controller has assigned
  `@post_type`
- **THEN** it SHALL render the taxonomy label links for that post type

### Requirement: A signed-out current user is resolved once per request
`cama_current_user` SHALL memoize a nil resolution so a signed-out request, or one carrying a stale
auth cookie, is not re-resolved on every call. An externally-assigned `CurrentRequest.user` SHALL still
be returned without re-resolving.

#### Scenario: The nil resolution is not repeated
- **WHEN** `cama_current_user` is called twice on a request with no resolvable user
- **THEN** the API/token resolution SHALL run only once

#### Scenario: An externally set user is honoured
- **WHEN** `CurrentRequest.user` is assigned before `cama_current_user` is called
- **THEN** that user SHALL be returned and no resolution SHALL run

### Requirement: Admin menu data attributes preserve quoted values
`parse_datas` SHALL parse a `data-*` attribute value that is single- or double-quoted, so a value may
contain the other quote character without being truncated.

#### Scenario: A single-quoted value containing double quotes survives
- **WHEN** a `datas` string contains `data-intro='<img style="…" />'`
- **THEN** the parsed `intro` value SHALL retain the full markup including the double quotes

### Requirement: Admin menu titles keep safe inline markup
An admin menu title SHALL render its inline formatting rather than as escaped text. A title that is
already an `ActiveSupport::SafeBuffer` (as core builds them) SHALL pass through unchanged; a plain-String
title SHALL be sanitized to a safe inline subset (`span`, `small`, `i`, `b`, `strong`, `em`, and `class`),
so scripts and event handlers are removed.

#### Scenario: A plugin's inline badge renders
- **WHEN** a menu title is the plain String `Orders <small class='label'>3</small>`
- **THEN** the rendered menu SHALL contain the `<small>` element, not escaped text

#### Scenario: A script or handler in a title is stripped
- **WHEN** a menu title contains a `<script>` element or an `on*` handler attribute
- **THEN** the rendered menu SHALL contain neither

### Requirement: Models registered via cf_add_model reach the placement dropdown
A model registered through `cf_add_model`, plus any a `custom_field_custom_models` hook appends, SHALL
appear in the custom-field-group placement dropdown. The writer and the dropdown SHALL read the same
`CurrentRequest` store.

#### Scenario: A registered model is offered for placement
- **WHEN** `cf_add_model(SomeModel)` is called before the custom-fields form renders
- **THEN** `SomeModel` SHALL be among the models the placement dropdown lists

### Requirement: The admin menu store supports in-place removal held across menu building
The admin menu store SHALL keep the same object identity across all menu operations, and `@_admin_menus`
SHALL alias it, so the `@_admin_menus.delete('key')` removal idiom in an `admin_before_load` hook removes
a menu that `admin_menu_draw` then omits.

#### Scenario: A reference held before an insert can still remove a menu
- **WHEN** a reference to the store is taken, a menu is inserted, and the reference then deletes a key
- **THEN** the store `admin_menu_draw` reads SHALL no longer contain that key

### Requirement: Frontend readers honour legacy compatibility ivars
When `CurrentRequest` state is unset, the frontend readers SHALL fall back to the legacy
`@object` / `@cama_visited_*` / `@user` instance variables a plugin front controller may have set, so
`the_title`, `is_home?`, menu-active and SEO helpers reflect that state. When `CurrentRequest` state is
present it SHALL take precedence.

#### Scenario: A plugin-set @object backs the frontend helpers
- **WHEN** a front controller assigns `@object` and no `CurrentRequest.frontend_object` is set
- **THEN** `the_title` SHALL return that object's title

#### Scenario: CurrentRequest takes precedence over the legacy ivar
- **WHEN** both `CurrentRequest.frontend_visited_post` and `@cama_visited_post` are set
- **THEN** the reader SHALL return the `CurrentRequest` value

