# Tasks — fix-namespaced-user-field-scope

## 1. Demodulize the user custom-field scope surfaces (commit 1)

- [x] 1.1 Write the red specs: namespaced-host `get_user_field_groups` derivation in
      `spec/models/meta_scope_resolution_spec.rb`, and the users placement option emission in a
      new `spec/requests/admin/settings/custom_fields_form_placement_spec.rb` (merged
      `static_system_info` stub); confirm both fail against current code.
- [x] 1.2 Fix `get_user_field_groups` (`parseCamaClass.demodulize`) and the form's users option
      (`PluginRoutes.get_user_class_name.demodulize`); confirm the specs go green.
- [x] 1.3 Add the green-by-design end-to-end pin `spec/requests/admin/user_field_values_spec.rb`
      (sibling of the widget round-trip pin): group placed on users, admin saves a field value,
      value reads back.

## 2. Repair task for legacy qualified placements (commit 2)

- [x] 2.1 Write `spec/lib/tasks/user_field_groups_rake_spec.rb`: re-keys the configured
      qualified placement, leaves other placements and `_fields` rows untouched, no-op without a
      namespaced config, re-keyed group becomes visible through `get_user_field_groups`.
- [x] 2.2 Add `lib/tasks/user_field_groups.rake` (`camaleon_cms:demodulize_user_field_groups`):
      config-derived key, single idempotent `update_all`, logged summary.

## 3. Verification and delivery

- [x] 3.1 Gates: `bin/rubocop -A` (touched files only, before specs), full `bin/rspec`,
      `bin/brakeman --no-pager`, `(cd spec/dummy && bin/rails zeitwerk:check)`.
- [x] 3.2 Archive the OpenSpec change on the branch (syncs the meta-scope-resolution delta) and
      commit it as part of the PR.
- [x] 3.3 Push, open the PR, then commit the short changelog entry referencing it (skip-ci
      directive, per Phase 3).
- [x] 3.4 Update the regression-audit memory (N5 → done) and the audit doc's fix-plan section.

## 4. Branch-review fixes (commits 5–7)

- [x] 4.1 Red spec: user round-trip with a `'SpecHost::Member'` config (the save filter keyed
      on the `'User'` literal drops the value); key both users controller call sites on
      `PluginRoutes.get_user_class_name.demodulize`; green.
- [x] 4.2 Switch the repair task's summary and no-op notice from `Rails.logger.info` to `puts`,
      red-first via stdout assertions in the task spec.
- [x] 4.3 Amend the change artifacts (proposal, design, delta + main spec, this file) and the
      changelog sentence that described the save filter as static; re-run the gates. This push
      also carries the PR's first CI run — the changelog commit's skip-ci directive at the
      previous head suppressed the run that should have covered commits 1–4.
