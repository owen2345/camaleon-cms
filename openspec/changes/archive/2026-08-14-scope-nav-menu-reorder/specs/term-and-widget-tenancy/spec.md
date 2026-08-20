# term-and-widget-tenancy

## ADDED Requirements

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
