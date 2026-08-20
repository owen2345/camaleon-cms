# Proposal: restore-runtime-compat-surfaces

## Why

The `CurrentRequest` refactors (#1178, #1182, #1183 Phase 6C) and the admin-menu rewrite moved runtime
state off controller instance variables and rebuilt the admin menu and helper surfaces. In doing so
they silently broke a set of contracts that plugins, themes and overridden admin views depend on, all
medium-severity findings in the 2.9.2→master regression audit:

- **M23** — `post_type_list_taxonomy` lost its 2-arg form's `@post_type` fallback, so overridden admin
  posts-index views (and `camaleon-ecommerce`'s products index) render empty taxonomy columns.
- **M16** — `cama_current_user` stopped memoizing a signed-out resolution, re-querying on every call.
- **M22** — `parse_datas` truncated a `data-*` value at the first quote (breaking core's own Menus
  tooltip), and menu titles were escaped whole, so a plugin's inline badge (`camaleon-ecommerce`)
  rendered as literal markup.
- **M18** — `cf_add_model` wrote `CurrentRequest` while the placement dropdown read the legacy ivar, so
  registered models never appeared.
- **M19** — the `@_admin_menus.delete('key')` removal idiom no-oped because the ivar was unsynced and
  the insert methods reassigned the store.
- **M20** — the frontend readers ignored the legacy `@object` / `@cama_visited_*` / `@user` ivars, so a
  plugin front controller setting them got nil-backed `the_title` / `is_home?` / SEO helpers.

## What Changes

Each finding is restored to its 2.9.2 contract (or, for M22b, to a safer superset), one commit per
finding, and pinned by a spec that reproduced the regression first. Grounded in the ecosystem survey
(`docs/ai/ecosystem.md`): M23 and M22b have live consumers; the `@cama_current_user` ivar-read half of
M16 and the `AdminController` `ApplicationHelper` include were **dropped** because no consumer needs
them.

- M23 restores the controller `@post_type` fallback.
- M16 memoizes the nil resolution via a `CurrentRequest.user_resolved` flag; an externally-set user is
  still honoured.
- M22a makes `parse_datas` quote-aware; M22b sanitizes a plain-String menu title to a safe inline
  subset (SafeBuffer titles pass through untouched) instead of escaping it.
- M18 shares one `CurrentRequest` store between `cf_add_model` and the dropdown.
- M19 aliases `@_admin_menus` onto the live store and makes the insert methods mutate in place.
- M20 restores the read-side legacy-ivar fallback in the frontend readers.

## Capabilities

### New Capabilities

- `runtime-compat-surfaces`: the admin and frontend runtime contracts these findings restore.

## Impact

- `app/helpers/camaleon_cms/admin/post_type_helper.rb`, `session_helper.rb`, `admin/menus_helper.rb`,
  `admin/custom_fields_helper.rb`, `frontend/{site,seo,content_select}_helper.rb`
- `app/controllers/camaleon_cms/admin_controller.rb`, `concerns/.../runtime_admin_menu_concern.rb`
- `app/models/current_request.rb`, `app/views/.../custom_fields/form.html.erb`
- Specs under `spec/helpers/`; `.rubocop_todo.yml` (ModuleLength ceiling for the M18 helper)
