## 1. Branch

- [x] 1.1 Create branch `security/fix-cross-site-field-group-injection` off the latest `master` and announce it — branched from `origin/master` at `26a665b4`, which includes the merged [#1216](https://github.com/owen2345/camaleon-cms/pull/1216)
- [x] 1.2 Confirm the triage verdict recorded in `proposal.md` still holds against current `master` before writing the fix — ✅ still legit. 7 of 8 placement families leak unchanged; `Site` is now clean because [#1216](https://github.com/owen2345/camaleon-cms/pull/1216) landed, so it drops out of scope here. Site B's own field-group list is still empty for every injected group

## 2. Reproduce first

- [x] 2.1 Add a request spec building two sites, signing in as a user who can manage custom fields on site A, and asserting that `POST` with `assign_group=Theme,<site B theme id>` persists no group and that `theme_b.get_field_groups` stays empty — `spec/requests/security/cross_site_field_group_injection_spec.rb`
- [x] 2.2 Extend it with the `NavMenu`, `PostType_Post` and `Plugin` families, plus four malformed-placement cases
- [x] 2.3 Add a case asserting an existing site A group cannot be moved onto a site B target via `update`
- [x] 2.4 Add a model spec pinning the leak mechanics: a group with `parent_id` of site A and a site B placement is returned by site B's `get_field_groups` and absent from `site_b.custom_field_groups` — `spec/models/custom_field_group_tenancy_spec.rb`. Passes before and after by design: the write-side guard stops new violations, it does not change how reads resolve, which is why the repair task exists
- [x] 2.5 Confirm 2.1–2.4 fail against unmodified `master` — 8 of 10 request examples fail. The two that pass are an empty `assign_group` (already refused by the `object_class` presence validation) and the `Site` pin from [#1216](https://github.com/owen2345/camaleon-cms/pull/1216)

## 3. Validate the submitted placement

- [x] 3.1 Add a private predicate to `Admin::Settings::CustomFieldsController` resolving a submitted `object_class`/`objectid` pair against `current_site`, per the table in `design.md` D1, defaulting to `objectid == current_site.id` for unlisted classes — `placement_owned_by_current_site?` / `owned_placement_ids`. `Plugin` added to the table during implementation; it leaks like the others and the form does not offer it, so it falls to the default arm otherwise
- [x] 3.2 Call it from `set_post_data`; on failure add an error to the field group and re-render `form` without persisting, for both `create` and `update` — `set_post_data` is a `before_action` for both, so rendering there halts the chain and neither action runs
- [x] 3.3 Handle malformed input — empty `assign_group`, missing id component, non-numeric id, id that does not exist. A blank class or an id that is not `/\A\d+\z/` fails the predicate before any query; a well-formed id that names nothing fails the ownership lookup
- [x] 3.4 Keep the `Site` pin added by [#1216](https://github.com/owen2345/camaleon-cms/pull/1216) as an explicit branch ahead of the general check, rather than making `Site` reject too — decided during implementation, recorded in `design.md` D4. #1216's request spec stays as written
- [x] 3.5 Confirm the specs from section 2 now pass — 10 examples, 0 failures; the pre-existing custom fields request and feature specs stay green

## 4. Cover the accepted paths

- [x] 4.1 Add a request spec asserting a group naming a post type, theme, and nav menu owned by the current site is persisted and returned by that record's `get_field_groups`
- [x] 4.2 Add a request spec asserting a group placed on the configured user model and on `Site` with `current_site.id` is still accepted
- [x] 4.3 Add a request spec asserting a class registered through the `custom_field_custom_models` hook is accepted when its id is `current_site.id`
- [x] 4.4 Add a request spec for editing a group whose current placement is absent from the select, confirming the reject path does not trap the administrator in an unsaveable form — an administrator can re-save such a group by choosing any target the site owns. Noted narrowing: a `Widget::Main` placement carrying a real widget id now falls to the default arm and would be refused if submitted, but the widget option is commented out in the form so this controller never legitimately produces one; programmatic creation via `widget.add_custom_field_group` is untouched

## 5. Re-homing Rake task

- [x] 5.1 Add `lib/tasks/cross_site_field_groups.rake` with `camaleon_cms:rehome_cross_site_field_groups`, resolving each group's placement target to its site and setting `parent_id` where it differs, per `design.md` D3. A Rake task rather than a migration, so a data-only repair does not force `spec/dummy/db/schema.rb` to be regenerated
- [x] 5.2 Implement resolution for `Site` and the user model (`objectid`), `PostType*` (post type's `parent_id`), `Theme`, `NavMenu`, `Plugin` (their `parent_id`), and `Post` / `Category*` (through their post type); skip unresolvable classes. `Widget::Main` and `PostTag` added too, since both are reachable placements
- [x] 5.3 Skip and log rows whose placement target no longer exists, without deleting them; report re-homed and skipped counts and do not abort on a single failure
- [x] 5.4 Add a spec under `spec/lib/tasks/`: an injected group is re-homed to the affected site, appears in that site's field-group list, and disappears from the injector's — `spec/lib/tasks/cross_site_field_groups_rake_spec.rb`
- [x] 5.5 Add specs asserting correctly owned groups and dangling-target groups are unchanged, that nothing is deleted, and that one failing row does not stop the run
- [x] 5.6 Confirm `spec/dummy/db/schema.rb` is unchanged (no schema change involved) — clean

## 6. Verification

- [x] 6.1 `bin/rspec` on the new and touched spec files — 26 examples, 0 failures
- [x] 6.2 `bin/rspec` full suite as a regression check, paying attention to `spec/requests/admin/settings/custom_fields_spec.rb` and `spec/features/admin/custom_fields_spec.rb` — 1012 examples, 0 failures
- [x] 6.3 `bin/rubocop -A` on touched files only — 4 files, no offenses (8 `RSpec/ExpectChange` autocorrections)
- [x] 6.4 `bin/brakeman --no-pager` — 0 security warnings
- [x] 6.5 `(cd spec/dummy && bin/rails zeitwerk:check)` — all is good

## 7. Documentation

- [x] 7.1 Resolve the disclosure question in `design.md` Open Questions with the maintainer before opening a public PR — the maintainer directed the work onto a public `security/` branch, which settles it: the fix and its reproducing specs are disclosed together, matching how prior security fixes in this repo have landed
- [x] 7.2 Open the PR following the constraints in `docs/ai/workflows.md` Phase 4 — [#1217](https://github.com/owen2345/camaleon-cms/pull/1217)
- [x] 7.3 Add a `CHANGELOG.md` entry under the unreleased section, marked as a security fix, describing the cross-site injection and telling multi-site operators to review their field-group lists after upgrading
- [x] 7.4 Run `/opsx:archive` on the branch and commit the result as part of the PR, before merge — archived as `2026-08-01-fix-cross-site-field-group-injection`, syncing the `custom-field-group-tenancy` capability into `openspec/specs/`
