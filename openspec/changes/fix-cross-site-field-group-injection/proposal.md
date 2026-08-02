## Why

In a multi-site install, a user who can manage custom fields on one site can inject a custom field group into **another** site's admin pages, and the target site's administrators can neither see nor delete it.

Found while investigating [issue #1124](https://github.com/owen2345/camaleon-cms/issues/1124). It is a distinct defect with a distinct root cause, so it is handled separately from `fix-site-settings-field-group-scope`.

### Triage verdict: legit

Per `docs/ai/workflows.md` Phase 2A.

**Proof of presence.** `bin/brakeman -z --only-files app/controllers/camaleon_cms/admin/settings/custom_fields_controller.rb` reports 0 warnings — expected, since this is a tenancy flaw rather than a pattern Brakeman detects. Confirmed instead by direct reproduction against `spec/dummy`: with a group owned by site A but stamped with site B's placement ids, every affected read on site B returns the injected group while site B's own admin list stays empty.

Re-confirmed against `master` at `26a665b4`, after [#1216](https://github.com/owen2345/camaleon-cms/pull/1216) landed:

```
site_a=1  site_b=17

theme_b.get_field_groups                => ["_inj_0"]      Theme
plugin_b.get_field_groups               => ["_inj_1"]      Plugin
menu_b.get_field_groups                 => ["_inj_2"]      NavMenu
pt_b.get_field_groups(kind: 'post_type')=> ["_inj_3"]      PostType
pt_b.get_field_groups('Post')           => ["_inj_4"]      PostType_Post
pt_b.get_field_groups('Category')       => ["_inj_5"]      PostType_Category
pt_b.get_field_groups('PostTag')        => ["_inj_6"]      PostType_PostTag

site_b.get_field_groups                 => []              Site: fixed by #1216
site_b.custom_field_groups              => []              site B's admin list: invisible
get_user_field_groups(site_b)           => []              User: not affected
```

### Root cause

Two independent gaps compose.

**Write side — no validation of the submitted placement.** `Admin::Settings::CustomFieldsController#set_post_data` splits `assign_group` straight into the two placement columns:

```ruby
@post_data[:object_class], @post_data[:objectid] = @post_data.delete(:assign_group).to_s.split(',')
```

The form only ever offers ids owned by `current_site`, but nothing enforces that server-side, so any `object_class,objectid` pair can be submitted.

**Read side — placement reads are not scoped to a site.** `CommonRelationships#custom_field_groups` uses `foreign_key: :objectid` with no `parent_id` filter, and the `Post`/`PostType` branches of `CustomFieldsRead#get_field_groups` query `CustomFieldGroup` directly with the same omission. So placement alone decides where a group renders, and ownership never enters the query.

`Site` is unaffected only because it overrides `custom_field_groups` with a tenancy-shaped association — the accident behind issue #1124. `User` is unaffected because `get_user_field_groups(site)` reads through `site.custom_field_groups`, which is `parent_id`-scoped.

### Impact

`custom_fields` is a role-manageable resource (`Ability#define_manage_rules`), so this is not limited to full administrators — any role granted `custom_fields` management on a site can do it. The injected group renders in the target site's admin forms, its fields are persisted against the target site's records, and because the target's field-group list is `parent_id`-scoped the group is invisible there and cannot be edited or removed through the UI.

Confined to multi-site installs where site administrators are not mutually trusted. Single-site installs are unaffected.

## What Changes

- `Admin::Settings::CustomFieldsController` validates the submitted `assign_group` placement against what `current_site` actually owns, and rejects the save with a form error when it does not match. Placement classes with a single legal target (`Site`, the configured user model, models registered through the `custom_field_custom_models` hook) are validated against `current_site.id`, which is exactly what the form emits for them.
- A Rake task, `camaleon_cms:rehome_cross_site_field_groups`, re-homes already-injected groups by setting `parent_id` to the site that owns the placement target, restoring the invariant that a group's owning site matches its placement target's site. This makes any pre-existing injection visible and deletable in the correct site's field-group list rather than silently deleting data.
- Reproducing specs for each affected placement family, asserting both that the crafted submission is rejected and that the target site's reads stay clean.

**Not** in scope: adding `parent_id` scoping to the read paths. See design.md D2 — the write-side choke point plus the re-homing task closes the hole, and retro-fitting a site filter onto `CommonRelationships` and the direct `CustomFieldGroup` queries is broad surgery with regression risk across every content type.

## Capabilities

### New Capabilities

- `custom-field-group-tenancy`: the invariant that a custom field group's owning site matches the site owning its placement target, how submissions are validated against it, and how pre-existing violations are repaired.

### Modified Capabilities

None. `custom-field-group-placement`, introduced by `fix-site-settings-field-group-scope`, covers which groups an owner renders. This change covers which placements an owner may be given, so the two are complementary rather than overlapping.

## Impact

**Code**

- `app/controllers/camaleon_cms/admin/settings/custom_fields_controller.rb` — placement validation in `set_post_data` (or an extracted private predicate), applied on `create` and `update`.
- `lib/tasks/cross_site_field_groups.rake` — the re-homing repair. No schema change, so `spec/dummy/db/schema.rb` is untouched.

**Behavior**

- Submitting a field group whose placement target is not owned by the current site is rejected with a form error instead of persisting.
- After the repair task runs, a previously injected group appears in the field-group list of the site whose pages it was rendering on, where an administrator can delete it.

**Sequencing with `fix-site-settings-field-group-scope`**

That change pins `objectid` to `current_site.id` for `object_class: 'Site'` submissions, a degenerate case of the validation added here. Whichever lands second should fold the pin into the general rule rather than leave two guards for the same class. The two changes touch the same method and will conflict textually; they are independent in behavior.

**Data**

One `UPDATE` on `custom_fields` rows whose placement target resolves to a site other than `parent_id`. Rows whose placement target no longer exists are left untouched and reported, not deleted.
