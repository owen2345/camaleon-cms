## 1. Branch

- [x] 1.1 Create branch `fix/site-settings-field-group-scope` off the latest `master` and announce it

## 2. Reproduce first

- [x] 2.1 Add a request spec for `GET /admin/settings/site` asserting that a field belonging to a `PostType_Post` group owned by the site is not rendered, while a field from the site's own `Site` group is — `spec/requests/admin/settings/site_custom_fields_spec.rb`, also covering the hidden Custom Configurations tab
- [x] 2.2 Add a request spec asserting that `PATCH` to `site_saved` succeeds when a required field of a foreign (`PostType_Post`) group is left unfilled, and that the site's own attributes persist — **passes before the fix**, because the block is client-side jQuery validation (`class="required"` on the input plus `panel.validate()`), not a server rejection. Kept as a regression guard, and the real symptom is reproduced instead by 2.2b
- [x] 2.2b Add a `:js` feature spec that fills in the site name and submits with a foreign required field present — `spec/features/admin/site_settings_custom_fields_spec.rb`. This is the true reproduction of "impossible to save"; it fails on unmodified `master` because the form never submits
- [x] 2.3 Add a model spec asserting `site.get_field_groups` excludes `PostType_Post`, `Theme`, `NavMenu`, and `User` groups owned by the same site — `spec/models/site_custom_field_groups_spec.rb`, plus the cross-site case and the unchanged theme/post-type scopes from section 6
- [x] 2.4 Confirm 2.1–2.3 fail against unmodified `master` — 2 of 4 request examples fail, the feature example fails, 4 of 8 model examples fail. The passing ones are the positive assertions and the cross-site case, which the current `parent_id` scoping already satisfies

## 3. Fix the read path

- [x] 3.1 Add a `when 'Site'` branch to `CustomFieldsRead#get_field_groups` returning `custom_field_groups.where(object_class: 'Site', objectid: id)`
- [x] 3.2 Confirm the specs from section 2 now pass — 13 examples, 0 failures

## 4. Pin site placement on write

- [x] 4.1 In `Admin::Settings::CustomFieldsController#set_post_data`, force `objectid` to `current_site.id` when the parsed `object_class` is `Site`
- [x] 4.2 Add a request spec: an admin of site A submitting `assign_group=Site,<site B id>` persists a group with `objectid` equal to site A's id, visible in `site_a.get_field_groups` and absent from `site_b.get_field_groups` — added to `spec/requests/admin/settings/custom_fields_spec.rb`; confirmed failing (`objectid` was 17) with the controller change stashed

## 5. Backfill Rake task

- [x] 5.1 ~~Generate an `up`-only migration~~ — **changed to a Rake task.** A migration under `db/migrate/` forces `spec/dummy/db/schema.rb` to be regenerated, which bumps the schema version and strips the hand-maintained footer block the file explicitly says to keep. Added `lib/tasks/site_custom_field_groups.rake` instead, following `lib/tasks/custom_fields_roles.rake`
- [x] 5.2 Add a spec: a legacy `Site` group with `NULL` `objectid` gets `objectid` from `parent_id` and becomes visible in that site's `get_field_groups` — `spec/lib/tasks/site_custom_field_groups_rake_spec.rb`
- [x] 5.3 Add a spec asserting rows with other `object_class` values, including those with `NULL` `objectid`, are untouched
- [x] 5.4 Add a spec asserting a site group with no owning site is skipped, and one asserting a single failing row does not abort the run
- [x] 5.5 Confirm `spec/dummy/db/schema.rb` is unchanged after `bundle exec rake app:db:test:prepare` — clean, no schema change involved

## 6. Cover the consequential fixes

- [x] 6.1 Add a model spec asserting `site.add_custom_field_group({ name: 'Group', slug: '_group' })` persists with `object_class: 'Site'` and `objectid` equal to the site's id, and is returned by `site.get_field_groups` (previously raised `Object class can't be blank`)
- [x] 6.2 Add a model spec asserting `site.set_field_value` binds to the site's own field when a `PostType_Post` group defines a field with the same slug — the post type group is created first on purpose, so `field_order` resolution would otherwise pick it; without that ordering the example passes on unmodified `master` and proves nothing
- [x] 6.3 Add a model spec asserting that destroying a site removes every group it owns via `parent_id` — site-placed, post-type-placed, and theme-placed — along with their fields. Passes both before and after, which is the point: it pins that `dependent: :destroy` covers what `get_field_groups` no longer does
- [x] 6.4 Add a model spec asserting `theme.get_field_groups` and `post_type.get_field_groups('Post')` are unchanged by the narrowing
- [x] 6.5 Confirm the section 2 and 6 model specs fail without the fix — 6 of 11 fail with the model change stashed, 0 with it applied

## 7. Verification

- [ ] 7.1 `bin/rspec` on the new and touched spec files
- [ ] 7.2 `bin/rspec` full suite as a regression check, paying attention to `spec/features/admin/settings_spec.rb`, `spec/features/admin/custom_fields_spec.rb`, and `spec/requests/admin/settings/`
- [ ] 7.3 `bin/rubocop -A` on touched files only
- [ ] 7.4 `bin/brakeman --no-pager`
- [ ] 7.5 `(cd spec/dummy && bin/rails zeitwerk:check)`

## 8. Documentation

- [ ] 8.1 Open the PR referencing issue #1124, following the PR constraints in `docs/ai/workflows.md` Phase 4
- [ ] 8.2 Add a `CHANGELOG.md` entry under the unreleased section covering both user-visible effects: site settings no longer render field groups of other content types, and `site.add_custom_field_group` / `site.set_field_value` now work correctly; note the narrowed `site.get_field_groups` contract for downstream plugins
- [ ] 8.3 Run `/opsx:archive` on the branch and commit the result as part of the PR, before merge
