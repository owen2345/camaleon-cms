# Scope nav-menu reorder destination to the current site (M10)

## Why

`Appearances::NavMenusController#reorder_items` read the destination menu foreign key straight from
`params[:nav_menu_id]` and wrote it as each item's `parent_id`. The items are looked up through
`current_site.nav_menu_items`, but the destination menu was not scoped, so a manager of one site
could re-home a menu item under another site's nav menu by posting that site's `nav_menu_id`. A
menu item's `parent_id` is its tenancy/placement key (which menu owns it), so this is the same
cross-site reparenting class as H8 — the last unscoped destination in the nav-menu controller
(`#add_items` already resolves the menu through `current_site`). Audit finding M10.

### Triage verdict: legit

`reorder_items` used the raw param as the destination FK. Reproduced in
`spec/requests/security/cross_site_nav_menu_reorder_spec.rb`: before the fix, posting another site's
`nav_menu_id` moves the item under that site's menu; after it, the foreign id is refused and the
item stays put.

## What Changes

- `reorder_items` resolves the root destination through `current_site.nav_menus.find(...)` — matching
  `#add_items` — so a `nav_menu_id` the current site does not own is refused (`RecordNotFound`, a 404,
  the same fail-closed outcome `add_items` already produces) and no item is moved. Nested calls pass
  an explicit parent-item id (itself resolved through `current_site.nav_menu_items`), so only the
  root destination needs scoping. Same-site reordering is unchanged.

## Notes for upgraders

- None. The admin nav-menu editor only ever reorders within a menu the current site owns.
