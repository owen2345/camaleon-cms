## Context

`CamaleonCms::CustomFieldGroup` rows live in `custom_fields` and carry two independent foreign keys:

```
custom_fields row (a group)
  parent_id                 -> tenancy:   which site owns/administers it
  object_class + objectid   -> placement: which record's admin page displays it
```

Every `TermTaxonomy` subclass receives a placement-shaped association from `CamaleonCms::CommonRelationships`:

```ruby
has_many :custom_field_groups, -> { where(object_class: object_class_name) },
         class_name: 'CamaleonCms::CustomFieldGroup', foreign_key: :objectid
```

`CamaleonCms::Site` overrides it with a tenancy-shaped one:

```ruby
has_many :custom_field_groups, class_name: 'CamaleonCms::CustomFieldGroup',
         foreign_key: :parent_id, dependent: :destroy, inverse_of: :parent
```

`CustomFieldsRead#get_field_groups` dispatches on class name and has explicit branches for `Category`/`PostTag`, `Post`, `NavMenuItem`, and `PostType`. Everything else falls through to `else -> custom_field_groups`. For themes, plugins, nav menus, and widgets that resolves to the placement association and is correct. For `Site` it resolves to the tenancy association, which is the defect.

The admin UI writes placement from a single `assign_group` select. `Admin::Settings::CustomFieldsController#set_post_data` splits it without validation:

```ruby
@post_data[:object_class], @post_data[:objectid] = @post_data.delete(:assign_group).to_s.split(',')
```

The site-settings save path already applies the placement contract: `SettingsController#site_saved` calls `set_field_values(cama_permitted_field_options('Site'))`, and `cama_custom_field_allowed_slugs('Site')` only permits slugs of fields under `object_class: 'Site'` groups. Render and persist therefore already disagree, and persist is the side that is right.

Behavior in this section was verified against `spec/dummy` with throwaway probe specs, not inferred from reading.

## Goals / Non-Goals

**Goals:**

- `/admin/settings/site` renders only field groups placed on the site, so required fields of other content types stop blocking the form.
- Make placement the single source of truth for what a site reads, and keep it consistent on write.
- Leave `Site#custom_field_groups` — the tenancy association and a public API — untouched.
- No existing group disappears from site settings as a result of the stricter read.

**Non-Goals:**

- Redefining `custom_field_groups` on `Site`, or unifying the two association shapes.
- The general cross-site `assign_group` injection. `CommonRelationships#custom_field_groups` applies no `parent_id` filter, so a group stamped with another site's theme, menu, post-type, user, or hook-registered model id renders on that site's admin pages while staying invisible in that site's own field-group list. That is a separate vulnerability with its own triage, branch, and reproducing test: `security/fix-cross-site-field-group-injection`.
- Cleaning up `custom_fields_relationships` rows written before `eba56d6f`, when `site_saved` passed `params[:field_options]` straight to `set_field_values` and foreign field values were persisted against the site. Those rows are unreachable and inert.

## Decisions

### D1 — Fix the reader, not the association

Add an explicit branch to `CustomFieldsRead#get_field_groups`:

```ruby
when 'Site'
  custom_field_groups.where(object_class: 'Site', objectid: id)
```

*Alternatives considered.*

- **Filter in `app/views/camaleon_cms/admin/settings/site.html.erb`.** Fixes the reported symptom only. It leaves `site.html.erb` and `theme.html.erb` structurally inconsistent for no reason, and leaves `add_custom_field_group`, `get_field_object`, and `set_field_value` wrong for sites.
- **Rename Site's tenancy association (e.g. `owned_custom_field_groups`) and let the `CommonRelationships` one stand as `custom_field_groups`.** Conceptually the cleanest, and it would make the `else` branch correct with no new branch at all. Rejected as a breaking public API change: `current_site.custom_field_groups` is used by `Admin::Settings::CustomFieldsController`, documented in `docs/MIGRATION_SELECT_EVAL.md`, and reachable from external plugin gems whose surface cannot be verified from this repo (AGENTS.md §6).

### D2 — Chain on the tenancy association rather than querying `CustomFieldGroup` directly

Issue #1124 suggests `CustomFieldGroup.where(object_class: 'Site', objectid: id)`. That drops the `parent_id` filter, which is currently the only thing keeping a group owned by another site off this site's settings page. Chaining `custom_field_groups.where(...)` keeps tenancy scoping and adds placement scoping.

The chained relation also carries all three attributes into `create!` — verified: `rel.create!(name: 'Scoped', slug: '_scoped')` yields `object_class: "Site", objectid: 1, parent_id: 1`. That is what fixes `add_custom_field_group` for sites.

### D3 — Match `objectid` strictly, and pin it on write

Matching `object_class` alone would be more forgiving of malformed rows, but leaves a group placed on `Site,<other site id>` rendering on the wrong site's page. Matching `objectid` strictly is the correct placement semantics, and D4 plus the controller guard remove the two ways a row could fail to match.

The controller guard is deliberately narrow — when `object_class == 'Site'`, force `objectid = current_site.id`. It is the exact invariant the read path depends on, it cannot break any downstream integration, and it does not attempt the general `assign_group` whitelist, which needs its own change because a whitelist strict enough to close the cross-site hole would also have to accommodate models registered through the `custom_field_custom_models` hook.

### D4 — Backfill `NULL` `objectid` on site-placed groups, via a Rake task

`CustomField` validates `object_class` presence but not `objectid`, so `site.custom_field_groups.create!(name: 'x', slug: '_x', object_class: 'Site')` persists with `objectid: nil` — verified. No shipped path produces one:

| Creation path | Produces `NULL` `objectid`? |
|---|---|
| Admin UI `assign_group` | No — the option value is always `Site,<current_site.id>` |
| `site.add_custom_field_group(...)` | No — raises `Object class can't be blank` today |
| `docs/MIGRATION_SELECT_EVAL.md` example | No — passes `objectid: site.id` |
| Hand-rolled `create!` omitting `objectid` | Possible |

Only the last is reachable, and only by bypassing `add_custom_field_group`. A backfill turns a small residual risk into none, and the failure mode it prevents — a group silently vanishing from the settings page — is the same class of bug being fixed here.

`objectid` is nullable and unvalidated for other placement classes too, but their reads are unchanged by this work, so the backfill is confined to `object_class = 'Site'`.

**The backfill is a Rake task, not a migration.** Adding anything under `db/migrate/` forces `spec/dummy/db/schema.rb` to be regenerated, which bumps the schema version and strips the hand-maintained footer block the file explicitly says to keep — the block that re-marks engine migrations as applied after `maintain_test_schema!` reloads the schema. A data-only repair must not touch `schema.rb` at all. `lib/tasks/site_custom_field_groups.rake` follows the existing `lib/tasks/custom_fields_roles.rake` pattern: `namespace :camaleon_cms`, `Rails.logger.info` progress, a per-record `rescue` so one bad row cannot abort the run, and an updated/skipped summary.

The trade-off is that the repair no longer runs automatically on upgrade. That is acceptable here: the rows it targets are not producible by any shipped code path, so most installations have none, and the CHANGELOG points anyone who hand-rolled such a group at the task.

### D5 — Rely on `dependent: :destroy` for site teardown

`CustomFieldsRead#_destroy_custom_field_groups` routes a site to `get_field_groups.destroy_all`, which today wipes every group in the site. After D1 it wipes only the site's own. `Site has_many :custom_field_groups, foreign_key: :parent_id, dependent: :destroy` removes the remainder, and each group's `has_many :fields, dependent: :destroy` removes its fields. Callback ordering is safe either way — both are `before_destroy` and both run. This is asserted by a spec rather than left as an assumption.

## Risks / Trade-offs

- **A downstream plugin reads `site.get_field_groups` as "every group in this site"** → The method's own docstring says "get custom field groups for current object", so the narrowing matches documented intent, and `site.custom_field_groups` still provides the tenancy meaning. Called out in the CHANGELOG.
- **A site's only groups were foreign ones, so the Custom Configurations tab disappears** → Intended. Those fields were unsubmittable and their values were discarded by `cama_permitted_field_options`. Called out in the CHANGELOG.
- **A `Site` group carries an `objectid` that is neither `NULL` nor the owning site's id** → Not producible by the admin UI, and D3's controller guard prevents it going forward. Such a row would become invisible in site settings; it is already effectively misfiled, and it remains visible and deletable in the admin field-group list, which is tenancy-scoped.
- **The Rake task touches production data** → It only writes rows matching `object_class = 'Site' AND objectid IS NULL AND parent_id IS NOT NULL`, and only ever copies `parent_id` into `objectid` on the same row. It is idempotent — a second run matches nothing.
- **An operator never runs the task** → Only affects installations holding a hand-rolled site group with a `NULL` `objectid`, which no shipped code path creates. Those groups become invisible on the settings page until the task runs; they remain intact in the database and visible in the admin field-group list, which is tenancy-scoped.

## Migration Plan

1. Ship the code change and the Rake task together.
2. Operators who created site field groups programmatically run `rake camaleon_cms:backfill_site_field_group_objectid`. It reports updated and skipped counts, and skips rows with no owning site rather than guessing.
3. Rollback: reverting the model change restores the previous behavior regardless of whether the task ran. The task itself has no inverse by design — restoring a `NULL` `objectid` would restore the defect it removes — but it writes only a value the row should always have carried, so leaving it applied after a revert is harmless.

## Open Questions

None. The three questions raised during exploration are settled: strict `objectid` matching (D3), the narrow controller guard in this change with the general whitelist split out (D3, Non-Goals), and a CHANGELOG entry covering both the render fix and the newly working `add_custom_field_group`.
