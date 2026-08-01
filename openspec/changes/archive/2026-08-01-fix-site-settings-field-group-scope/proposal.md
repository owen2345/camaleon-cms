## Why

[Issue #1124](https://github.com/owen2345/camaleon-cms/issues/1124) reports that `/admin/settings/site` renders custom field groups that belong to other content types. Because those groups can contain required fields, their presence makes the site settings form unsubmittable — the admin is blocked by validation on fields that do not apply to the site and whose values the server would discard anyway.

The root cause is that `CustomFieldGroup` carries two independent foreign keys, and `Site` conflates them:

- `parent_id` — **tenancy**: which site owns and administers the group.
- `object_class` + `objectid` — **placement**: where the group is meant to be displayed.

Every other `TermTaxonomy` subclass reads its groups through the placement-shaped association defined in `CamaleonCms::CommonRelationships` (`where(object_class: <class>)`, `foreign_key: :objectid`). `CamaleonCms::Site` overrides `custom_field_groups` with a tenancy-shaped association (`foreign_key: :parent_id`), and `CustomFieldsRead#get_field_groups` has no `Site` branch, so `Site` falls through to `else` and receives every group in the site.

Confirmed against the dummy app — for a site holding one `Site`, one `PostType_Post`, and two `Theme` groups:

```
site.get_field_groups              => _default (Theme), _site_g (Site), _pt_g (PostType_Post), _theme_g (Theme)
theme.get_field_groups             => _default (Theme), _theme_g (Theme)          correct
post_type.get_field_groups('Post') => _pt_g (PostType_Post)                       correct
```

The save path already encodes the intended contract and disagrees with the render path: `SettingsController#site_saved` calls `set_field_values(cama_permitted_field_options('Site'))`, which permits only slugs of fields under `object_class: 'Site'` groups. Foreign fields are therefore rendered, marked required, and blocked client-side — and their values would be silently dropped even if submitted. Only the read side is wrong.

## What Changes

- `CustomFieldsRead#get_field_groups` gains an explicit `when 'Site'` branch returning `custom_field_groups.where(object_class: 'Site', objectid: id)`, so a site reads only the groups placed on it. `Site#custom_field_groups` keeps its current tenancy meaning and public contract.
- `Admin::Settings::CustomFieldsController#set_post_data` forces `objectid` to `current_site.id` when the submitted `object_class` is `Site`, so the invariant the read path now relies on cannot be broken by a crafted `assign_group` parameter.
- A Rake task, `camaleon_cms:backfill_site_field_group_objectid`, backfills `objectid` from `parent_id` for existing `object_class: 'Site'` groups that have a `NULL` `objectid`, so no pre-existing group disappears from site settings under the stricter scope. It is a Rake task rather than a migration because a data-only repair must not force `spec/dummy/db/schema.rb` to be regenerated — see design.md D4.
- Two latent `Site` defects are fixed as a consequence, both verified against the dummy app:
  - `site.add_custom_field_group(...)` currently raises `ActiveRecord::RecordInvalid: Object class can't be blank`, because `create!` runs through the unscoped tenancy association and nothing stamps `object_class`. Under the scoped relation it stamps `object_class` and `objectid` and succeeds.
  - `site.get_field_object` / `site.set_field_value` currently search every group in the site for a slug, so a site-level write could bind to a field id belonging to a post or theme group. They are now confined to the site's own groups.

Not breaking: `Site#custom_field_groups` is unchanged, so `current_site.custom_field_groups` — used by `Admin::Settings::CustomFieldsController`, documented in `docs/MIGRATION_SELECT_EVAL.md`, and reachable from external plugin gems — keeps returning every group in the site.

**Out of scope.** A separate cross-site injection exists in the same `assign_group` parameter and is handled by its own change (`security/fix-cross-site-field-group-injection`). `CommonRelationships#custom_field_groups` applies no `parent_id` filter, so a group stamped with another site's theme/menu/post-type id renders on that site's admin pages while remaining invisible in that site's own field-group list. The narrow `Site` guard here does not address the other `object_class` families.

## Capabilities

### New Capabilities

- `custom-field-group-placement`: which custom field groups a given owner renders, and how a group's placement (`object_class` + `objectid`) is established and kept consistent with its tenancy (`parent_id`).

### Modified Capabilities

None. No existing spec in `openspec/specs/` covers custom field group placement.

## Impact

**Code**

- `app/models/concerns/camaleon_cms/custom_fields_read.rb` — new `when 'Site'` branch in `get_field_groups`.
- `app/controllers/camaleon_cms/admin/settings/custom_fields_controller.rb` — `set_post_data` pins `objectid` for `Site` placements.
- `lib/tasks/site_custom_field_groups.rake` — the backfill task. No schema change, so `spec/dummy/db/schema.rb` is untouched.

**Behavior**

- `/admin/settings/site` "Custom Configurations" tab shows only groups placed on the site. The tab is hidden entirely when the site has none, since the view already gates on `groups.present?`.
- Sites whose only groups were foreign ones lose the tab. This is the fix, not a regression: those fields could never be saved.

**Read paths affected by the narrowed `Site` scope**

- `app/views/camaleon_cms/admin/settings/site.html.erb` — the reported bug.
- `CustomFieldsRead#_destroy_custom_field_groups` — for a site this narrows from "all groups in the site" to "the site's own groups". Safe: `Site has_many :custom_field_groups, dependent: :destroy` (tenancy) already removes the rest. Covered by a spec rather than assumed.
- `CustomFieldsRead#get_field_object`, `#set_field_value`, `#add_custom_field_group` — narrowed, which is the intended correction.

**Downstream**

`site.get_field_groups` is public surface. Any external plugin using it as "every group in this site" sees a behavior change; its own docstring says "get custom field groups for current object", so the narrowing matches documented intent. `site.custom_field_groups` remains available for the tenancy meaning.

**Data**

The backfill task writes `custom_fields` rows with `object_class = 'Site'`, a `NULL` `objectid`, and a non-null `parent_id`. `objectid` has no presence validation, so such rows are constructible; no shipped code path produces them, so most installations have nothing to repair and never need to run the task.
