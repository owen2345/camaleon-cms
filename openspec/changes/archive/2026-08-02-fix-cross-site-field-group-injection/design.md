## Context

A custom field group carries tenancy in `parent_id` and placement in `object_class` + `objectid`. Nothing enforces that the two agree.

```
   submitted assign_group           persisted row                 rendered on
   "Theme,<site B theme id>"  -->   parent_id:   site A     -->   site B theme settings
                                    object_class: Theme           (placement wins)
                                    objectid:    B's theme
                                                              -->  site A field-group list
                                                                   (tenancy wins — B never sees it)
```

Write side, `Admin::Settings::CustomFieldsController#set_post_data`:

```ruby
@post_data[:object_class], @post_data[:objectid] = @post_data.delete(:assign_group).to_s.split(',')
```

The select in `custom_fields/form.html.erb` only offers ids drawn from `current_site` — post types from `current_site.post_types`, menus from `current_site.nav_menus`, `Theme,<current_theme.id>`, and `<Class>,<current_site.id>` for `Site`, the user model, and hook-registered models. None of that is re-checked server-side.

Read side, placement decides everything:

- `CommonRelationships#custom_field_groups` — `where(object_class: <class>)`, `foreign_key: :objectid`, no `parent_id`.
- `CustomFieldsRead#get_field_groups` `Post` and `PostType` branches — direct `CamaleonCms::CustomFieldGroup.where(...)` on placement columns only.

`custom_fields` is a role-manageable resource in `Ability#define_manage_rules`, so the required privilege is "can manage custom fields on some site", not "is a superuser".

All of the above was reproduced against `spec/dummy`; see proposal.md for the enumeration.

## Goals / Non-Goals

**Goals:**

- No submission can place a field group on a record the current site does not own.
- Any group already injected becomes visible and removable by the administrators of the site it renders on.
- A reproducing spec exists for each affected placement family, failing before the fix.

**Non-Goals:**

- Scoping the read paths by site (D2).
- Issue #1124's site-settings scope, handled by `fix-site-settings-field-group-scope`.
- Reworking the `assign_group` select's wire format. Its `Class,id` encoding stays; only server-side validation is added.
- Auditing other admin controllers that split composite parameters. If the pattern recurs it deserves its own sweep.

## Decisions

### D1 — Validate at the write choke point

Both `create` and `update` route through `set_post_data`, so one validation covers every path that writes placement from user input. The check resolves the submitted `object_class` to an ownership query against `current_site`:

| Placement class | Valid ids |
|---|---|
| `PostType`, `PostType_Post`, `PostType_Category`, `PostType_PostTag` | `current_site.post_types` |
| `Theme` | `current_site.themes` |
| `NavMenu` | `current_site.nav_menus` |
| `Post` | `current_site.posts` |
| `Category`, `Category_Post` | `current_site.full_categories` |
| `Site`, configured user model, hook-registered models | `current_site.id` |

The last row is the default arm rather than an enumeration. Every "other" option the form emits is `<Class>,<current_site.id>`, including models contributed through the `custom_field_custom_models` hook — so requiring `objectid == current_site.id` for any class not named above admits every legitimate hook model without this controller needing to know their names. An allow-list of class names would have to be extended by every downstream plugin; keying on the id instead does not.

*Alternative considered.* A model-level validation on `CustomFieldGroup`. Rejected: the model has no notion of "the current site", and legitimate programmatic creation (`theme.add_field_group`, seeds, plugin installers) sets placement directly and would have to be exempted. The exposure enters through one controller; that is where the guard belongs.

### D2 — Do not add site scoping to the read paths

A `parent_id` filter on `CommonRelationships#custom_field_groups` plus the direct `CustomFieldGroup` queries would be defense in depth, and was considered.

Rejected for this change:

- `CommonRelationships` is included by models with no site association (`PostComment`, the user model), so the filter cannot be expressed uniformly in the concern.
- The `Post` branch already builds a three-way `OR` across post, post type, and category placements. Adding ownership to it is a non-trivial query change on the hottest custom-field read in the codebase.
- Any group whose `parent_id` was never stamped would silently vanish from every content type at once — the same failure mode as issue #1124, at much greater blast radius.

D1 stops new violations and D3 repairs existing ones, which closes the hole. Read-side hardening remains a reasonable follow-up once placement/tenancy agreement is known to hold in the field.

### D3 — Repair by re-homing, not by deleting, via a Rake task

Existing injected rows keep rendering after D1, and the affected site still cannot see them. `lib/tasks/cross_site_field_groups.rake` resolves each group's placement target, finds that target's site, and rewrites `parent_id` when it differs.

**A Rake task, not a migration**, for the same reason as `fix-site-settings-field-group-scope` D4: anything under `db/migrate/` forces `spec/dummy/db/schema.rb` to be regenerated, which bumps the schema version and strips the hand-maintained footer block that file asks callers to keep. A data-only repair must not touch `schema.rb`. It follows `lib/tasks/custom_fields_roles.rake`: `namespace :camaleon_cms`, `Rails.logger.info` progress, a per-record `rescue` so one bad row cannot abort the run, and a re-homed/skipped summary.

The cost is that the repair no longer runs automatically on upgrade, which matters more here than it did for #1216 — those rows were not producible by any shipped path, whereas these are the residue of an actual exploit. Mitigated by making the task prominent in the CHANGELOG and release notes rather than by reaching for a migration.

*Why re-home rather than delete.* Deleting destroys field definitions and, through `dependent: :destroy` on the group's fields, their values. A mismatch is not proof of attack — it can equally be a plugin that stamped `parent_id` from the wrong site. Re-homing is non-destructive, restores the invariant, and surfaces the group in the list of the site that was actually affected, where an administrator can judge it and delete it.

*Why not leave repair to the administrator.* Nothing in the UI reveals these rows to the site they affect, so "leave it to the administrator" means "leave it in place".

Resolution is best-effort: a placement whose target no longer exists is skipped, not deleted, and the count of skipped rows is logged. `Site` and the user model resolve to `objectid` itself; `PostType*` to the post type's `parent_id`; `Theme`, `NavMenu`, `Plugin` to their `parent_id`; `Post` and `Category*` through their post type. Classes the task cannot resolve are skipped.

### D4 — Reject rather than coerce

`fix-site-settings-field-group-scope` pins `objectid` to `current_site.id` for `object_class: 'Site'`, because that class has exactly one legal value and coercion cannot misfile anything. That reasoning does not generalize: for a post type or menu there are many legal targets, and silently substituting one would attach the group to a record the submitter did not choose. So the general rule rejects and re-renders the form with an error, consistent with how `_save_fields` already reports field-level failures.

**The `Site` pin is kept, not replaced.** #1216 landed first, and its coercion is retained as an explicit branch ahead of the general check rather than folded into it. Making `Site` reject too would be more uniform, but it would change behaviour already shipped and rewrite that PR's request spec to buy consistency in a case where coercion is provably safe — the form only ever emits `Site,<current_site.id>`, and there is no other legal value to misfile to. The cost is one special case in the validator, which the code comments as such.

## Risks / Trade-offs

- **The re-homing task moves a group an administrator was relying on** → It only moves groups whose owning site already disagrees with their placement, and it moves them to the site whose pages render them, which is where they were already in effect. Non-destructive and visible afterwards in the target's field-group list. Called out in the CHANGELOG.
- **A downstream plugin creates groups through the admin endpoint with a placement scheme the table does not cover** → The default arm accepts any unknown class whose `objectid` is `current_site.id`, which is what the form emits for hook-registered models. A plugin using a different scheme would need to create groups programmatically, which this change does not touch.
- **`Widget::Main` placements** → The widget option is commented out in the form, so widget groups are created programmatically and are unaffected by D1. They are still resolvable by D3 through their `parent_id`.
- **Editing a group whose current placement is not in the select** → Pre-existing behavior: the JS preselect finds no matching option and `assign_group` is a required field, so the administrator must choose a valid target. D1 does not make this worse, but the interaction should be confirmed by a spec so the reject path does not become an edit trap.
- **Textual conflict with `fix-site-settings-field-group-scope`** → Both edit `set_post_data`. Independent in behavior; resolve by folding the `Site` pin into the general rule.

## Rollout Plan

1. Ship D1 and D3 together. D1 alone leaves existing injections in place and invisible; D3 alone leaves the door open.
2. The task iterates `custom_fields` group rows (`object_class != '_fields'`), resolves each placement target's site, and updates `parent_id` where it differs. Skipped rows are logged with their ids.
3. Rollback: `up`-only. Restoring the previous `parent_id` values would re-hide the groups from the sites they affect. Reverting the controller change alone restores the previous write behavior.
4. Because this is a security fix, note in the release notes that multi-site operators should review their field-group lists after upgrading — a group that appears newly is one that was already rendering on their pages.

## Open Questions

- Should the task log skipped and re-homed ids at `info` level, or write a summary an operator can retrieve later? Logging is the smaller change; a persisted report is more useful to a multi-site operator triaging after the fact.
- Does this warrant coordinated disclosure ahead of the fix landing publicly? It requires an authenticated, custom-field-managing user on a multi-site install, which is narrower than an unauthenticated flaw, but it is a real cross-tenant boundary break. Maintainer's call.
