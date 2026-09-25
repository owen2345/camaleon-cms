# Confine admin custom-field saves to the record's own field groups

## Why

`CamaleonCms::Admin::CustomFieldsConcern#cama_custom_field_allowed_slugs(object_class)` permits the slug
of every field under any group placed with that `object_class`, whatever the group's `objectid` and
owning site. So a post type save accepts slugs registered on every other post type, the site, theme and
user saves accept slugs registered by another site, a widget assignment save accepts another widget's
slugs, and a plugin calling `cama_permitted_field_options('Plugin')` (camaleon-post-clone PR #3, the
generator template) accepts slugs registered by any other plugin. For such a slug `set_field_values`
finds no field on the record, so it stores the row under the client-supplied `custom_field_id`, which
also picks the save-time gate the value gets. Low severity: the row lands on a record the caller may
edit anyway, and only a theme reading that slug on that record would render it.

The nav menu item save has a second, worse problem: it permits `'NavMenuItem'` groups while the
custom-fields form places a menu's groups as `'NavMenu'`, so every custom-field value submitted from a
menu item's settings form is dropped (external item options share the scope).

### Triage verdict: legit

The allow-list query has no `objectid` or `parent_id` condition. Reproduced in
`spec/requests/security/field_options_owner_scope_spec.rb` (a slug registered only on a sibling record
is stored) and `spec/requests/security/nav_menu_item_field_options_spec.rb` (a value for a group
placed through the form is dropped); both fail before the fix.

## What Changes

- `cama_permitted_field_options` and `cama_custom_field_allowed_slugs` take an optional
  `field_groups:` keyword: the field-group relation the save's form renders. The allow-list is then
  the slugs of those groups' fields within `object_class`. Without it the helpers behave as today
  (every group of the class), so no released caller changes.
- Every core save passes the groups its form renders: site, theme (both payloads), post type, post,
  draft, category, post tag, user, widget assignment, nav menu item.
- The nav menu item save and the external item options permit against the item's menu, placement
  `'NavMenu'`, matching what the custom-fields form stores and the item form renders.
- The plugin generator template passes `@plugin.get_field_groups`.
- `docs/ai/ecosystem.md` records the hardening; `docs/upgrading-to-2.9.5.md` tells plugin authors how
  to opt in.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `custom-field-value-filtering`: an admin save stores only the fields its form offers for the record
  being saved; the nav menu item save accepts the groups placed on its menu; the shared permit keeps
  its class-wide default for callers that name no groups.

## Impact

- `app/controllers/concerns/camaleon_cms/admin/custom_fields_concern.rb` (the keyword).
- `app/controllers/camaleon_cms/admin/{settings,categories,post_tags,posts,users}_controller.rb`,
  `admin/posts/drafts_controller.rb`, `admin/settings/post_types_controller.rb`,
  `admin/appearances/widgets/assign_controller.rb`, `admin/appearances/nav_menus_controller.rb`.
- `lib/generators/camaleon_cms/gem_plugin_template/.../admin_controller.rb`.
- Ecosystem: `cama_contact_form`, `camaleon-cms-seo`, `camaleon-post-clone` (PR #3) and every theme
  keep working unchanged; the keyword is opt-in. The `camaleon-post-clone / RSpec` check exercises the
  class-only call.

## Notes for upgraders

- A menu item's custom fields placed through the custom-fields form are stored again; they were
  silently dropped since the mass-assignment hardening in 2.9.3.
- Plugin controllers confining a settings save can pass `field_groups: @plugin.get_field_groups` to
  keep other plugins' slugs out; without it nothing changes.
