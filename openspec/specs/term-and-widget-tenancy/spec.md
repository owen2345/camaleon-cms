# term-and-widget-tenancy Specification

## Purpose

Keep taxonomy terms and widget assignments anchored to the site that owns them. `parent_id` doubles
as the tenancy foreign key on taxonomies — for a post type it is `site_id` itself, for a post tag the
owning post type, and for a category its place in a post type's tree — and a widget assignment's
`sidebar_id`/`widget_id` name its tenant-scoped sidebar and widget. None of these may be reassigned
across sites through admin mass assignment: the tenancy keys are set from the owning association and
never from the request, and the one legitimately caller-chosen value — a category's parent — is
accepted only from the post type's own tree.
## Requirements
### Requirement: Taxonomy tenancy foreign keys are not reassignable across tenants

The admin term controllers SHALL NOT let the `parent_id` foreign key that carries a taxonomy's tenancy
be reassigned across sites through mass assignment.

For a **post type**, `parent_id` is its `site_id` (`alias_attribute`); for a **post tag**, it is the
owning post type. On both, `parent_id` is set from the owning association at create and SHALL NOT be
accepted from the request on `create` or `update` — the admin form submits it only as a hidden mirror
of the current value.

For a **category**, `parent_id` is a hierarchy choice, so it SHALL be accepted only when it names the
category's own post type or a category within that post type (the post type's site- and id-scoped set,
`full_categories`); any other value SHALL be rejected before the record is written. This applies to
`create` and `update`.

#### Scenario: A submitted parent_id cannot move a post type to another site

- **WHEN** a manager sends `PATCH /admin/settings/post_types/<ID>` with `post_type[parent_id]` naming another site
- **THEN** the post type's `site_id` is unchanged

#### Scenario: A category cannot be reparented under another site's post type or category

- **WHEN** a manager sends `PATCH /admin/post_type/<PT>/categories/<ID>` with `category[parent_id]` naming a post type or category owned by another site
- **THEN** the request is refused and the category's `parent_id` and `site_id` are unchanged

#### Scenario: A category can still be reparented under a category of its own post type

- **WHEN** a manager sends `PATCH /admin/post_type/<PT>/categories/<ID>` with `category[parent_id]` naming another category of the same post type
- **THEN** the category is reparented under that category

#### Scenario: A submitted parent_id cannot move a post tag to another post type

- **WHEN** a manager sends `PATCH /admin/post_type/<PT>/post_tags/<ID>` with `post_tag[parent_id]` naming another site's post type
- **THEN** the tag's `parent_id` is unchanged and stays its own post type

### Requirement: A widget assignment cannot be re-pointed to another tenant's sidebar or widget

`Appearances::Widgets::AssignController#update` SHALL NOT accept `sidebar_id` (post_parent) or
`widget_id` (visibility) from the request body. Both are set from the route-scoped, current-site
`@sidebar` and the looked-up `@widget` when the assignment is created, and must not be reassigned on
update, so an assignment cannot be moved into another site's sidebar or re-pointed at another site's
widget. Reordering (including moves) is handled by the current-site-scoped `sidebar#reorder` action.

#### Scenario: A submitted sidebar_id does not move the assignment to another site's sidebar

- **WHEN** a widget manager sends `PATCH` to a sidebar assignment with `assign[sidebar_id]` naming another site's sidebar
- **THEN** the assignment stays in its own sidebar

#### Scenario: A submitted widget_id does not re-point the assignment at another site's widget

- **WHEN** a widget manager sends `PATCH` to a sidebar assignment with `assign[widget_id]` naming another site's widget
- **THEN** the assignment stays pointed at its own widget

#### Scenario: The editable fields still apply

- **WHEN** a widget manager sends `PATCH` to a sidebar assignment with a new `title` and `content`
- **THEN** those fields are updated

### Requirement: A nav-menu item cannot be reordered into another tenant's menu

`Appearances::NavMenusController#reorder_items` SHALL resolve the destination menu through the
current site (`current_site.nav_menus`) before writing it as an item's `parent_id`, so a menu item
cannot be re-homed under a nav menu owned by another site. A `nav_menu_id` the current site does not
own SHALL be refused and no item moved. Nested reorder calls carry an explicit parent-item id, itself
resolved through the current site's items, so only the root destination is taken from the request.

#### Scenario: A submitted nav_menu_id cannot move an item to another site's menu

- **WHEN** a manager POSTs `reorder_items` with a `nav_menu_id` naming another site's nav menu
- **THEN** the request is refused and the item's `parent_id` is unchanged

#### Scenario: Reordering within the current site's own menu still works

- **WHEN** a manager POSTs `reorder_items` with a `nav_menu_id` the current site owns
- **THEN** the items are reordered under that menu as before

