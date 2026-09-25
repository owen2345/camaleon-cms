## Context

See proposal.md for the finding. The pieces as they stand on `master`:

- **The permit** is `CustomFieldsConcern#cama_permitted_field_options(object_class, param_key:)`. It
  reads `cama_custom_field_allowed_slugs(object_class)`, whose query is
  `CustomField.where(parent_id: CustomField.where(object_class:).select(:id), object_class: '_fields')`:
  placement class only, no `objectid`, no `parent_id`.
- **A group's placement** is `object_class` + `objectid` (`custom-field-group-placement`), its tenancy
  `parent_id` (`custom-field-group-tenancy`). The reads that decide what a form renders are per model:
  `Plugin`/`Theme`/`Widget::Main` use the `custom_field_groups` association (class + own id);
  `Site#get_field_groups` adds `parent_id`; `PostType#get_field_groups(kind)` takes a kind
  (`'post_type'` for the post type's own fields, `'Post'`/`'Category'`/`'PostTag'` for its children);
  `Post#get_field_groups` is an OR over per-post, post-type and category groups; a user's groups come
  from `get_user_field_groups(site)`, keyed on `parent_id` with no `objectid`; a menu item's groups are
  `main_menu.custom_field_groups`, placement `NavMenu`.
- **The value writer** `set_field_values` resolves `custom_field_id` from the slug through the
  record's own groups and falls back to the client-supplied id for a slug it cannot find.
- **Ecosystem:** `cama_contact_form`, `camaleon-cms-seo` and the themes do not call the permit;
  `camaleon-post-clone` PR #3 and the generator template call it with `'Plugin'`; four plugins pass
  raw params to `set_field_values` (`docs/ai/ecosystem.md`, hardening hazards).

## Goals / Non-Goals

**Goals:**
- Permit equals render: each save accepts exactly the slugs its form offers for the record.
- One helper, opt-in narrowing, no change for a caller that does not opt in.

**Non-Goals:**
- **Widening the post save** to per-post and category-inherited groups: the `'PostType_Post'` scope
  was kept deliberately (concern comment, archived `scope-draft-field-options`); this change narrows
  it to the post's own post type and nothing more.
- **Repairing value rows** already stored under a foreign slug: they are inert unless a theme reads
  that slug on that record, and the scan-and-reject gate ran on them at save.
- **Restoring hook-added external menu item options** (`menu_external_form` inputs named
  `options[<key>]`): the mass-assignment hardening confined those keys to custom-field slugs; this
  change only corrects which groups those slugs come from.

## Decisions

### D1. The keyword takes the field-group relation the form renders, not a record

`field_groups:` receives what the save's form passes to the `custom_fields/render` partial under the
same local name: `@site.get_field_groups`, `current_theme.get_field_groups`,
`@post_type.get_field_groups('post_type')`, `@post_type.get_field_groups('Category')`,
`current_site.custom_field_groups` intersected by the configured user scope (what
`get_user_field_groups` returns in a host app, where the user class carries the configured name),
`@assigned.widget.get_field_groups`,
`@nav_menu_item.get_field_groups`. Permit and render then agree by construction, including where the
read is keyed on tenancy rather than placement (users) or takes a kind (post types).

**Alternative rejected: `record:` narrowing to `record.get_field_groups`.** It fits plugins, themes,
sites, categories and tags, but `post_type.get_field_groups` with no kind returns the *posts'* groups,
not the post type's own, `assigned.get_field_groups` looks for `Assigned` groups where the form
renders the widget's `Main` groups, and no record's `get_field_groups` returns a user's groups.

**Alternative rejected: an owner record narrowing to `(object_class, owner.id)`.** One line, and the
tuple the custom-fields form stores, but a user's groups render by `parent_id` with any `objectid`, and
a `Site` group saved without an `objectid` (the `backfill_site_field_group_objectid` task exists for
those) would render and be refused. The relation form has no such gap.

### D2. `object_class` stays, as the intersect

The positional argument keeps its meaning and the call sites their shape. With `field_groups:` it
narrows the relation (`where(object_class:)`): the post save passes the post type's `'Post'` groups and
keeps `'PostType_Post'`, so a caller passing `post.get_field_groups` would still get only the post
type's scope. A caller whose `object_class` and groups disagree gets an empty allow-list, which the
existing blank guard turns into "nothing written, nothing wiped".

### D3. The default stays class-wide

`field_groups: nil` runs today's query. Released callers (`camaleon-post-clone` PR #3, generated
plugins) keep working; the requirement pins the default so a later tightening is a decision. The
generator template opts in, so new plugins start confined.

### D4. The nav menu item permits its menu's `NavMenu` groups

`'NavMenuItem'` came in with the mass-assignment hardening (af554507) while the form has always
stored `NavMenu,<menu id>` and the item form renders `main_menu.custom_field_groups`. The item save
and `permitted_external_options` move to `'NavMenu'` with the menu's groups. The existing
mass-assignment spec, which hand-creates a `'NavMenuItem'` group with no `objectid`, places its group
as the form does.

### D5. One subquery, order dropped

`CustomField.where(parent_id: groups.unscope(:order).select(:id), object_class: '_fields')`: the
relations carry the model's `field_order` default scope, which has no place inside an `IN (...)`.

## Risks / Trade-offs

- [A mis-stamped cross-site group renders on a site that does not own it] → the permit follows the
  render side, as `custom-field-group-tenancy` decided for reads; the `rehome_cross_site_field_groups`
  task is the repair.
- [A plugin passes an Array instead of a relation] → `NoMethodError` on `where`; the keyword is
  documented as a relation and the template shows the call.
- [A core form changes what it renders without changing the save] → the request specs pair each save
  with a slug registered on the record and one on a sibling, so a one-sided change goes red.
