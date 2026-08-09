## Why

The 2026-08 regression audit batched the `common_relationships.rb` findings as PR 5 (M9, M8,
M7-doc, N4). During implementation the maintainer directed a simpler resolution for the naming
half, and live verification corrected the cascade finding:

- **M9 / M8** — the unreleased scope rename (`name.demodulize` →
  `name.delete_prefix('CamaleonCms::')`) re-keyed every nested engine scope (`'Main'` →
  `'Widget::Main'`) and every namespaced host-model scope (`'User'` → `'Admin::User'`). That
  stranded all rows 2.9.2-era installs ever wrote (M9 for host models, M8 for widget fields) and
  would have required a compatibility seam plus a repair rake task. **Maintainer decision:
  revert the rename entirely** — pure churn for an unreleased change — instead of compensating
  for it.
- **M7** — new `Widget::Assigned` rows write the compact `post_class` STI discriminator; 2.9.2
  reads only the full name, so a rollback hides assignments created on master. A separate
  mechanism from the `object_class` scopes; documented, not code-fixed.
- **N4** — `41c16a7d` added `dependent: :delete_all` to the concern's `custom_fields` and
  `custom_field_groups`. Live verification corrected the audited claim: teardown is owned by the
  placement hook (`CustomFieldsRead#_destroy_custom_field_groups`), which runs first and
  destroys groups **with callbacks** at both revisions — the `delete_all` was inert for every
  hook-carrying model. It bit only hook-less includers (`PostComment`), where destroy
  raw-deleted group rows while orphaning their fields and option metas.

## What Changes

- The `object_class` scopes return to the demodulized 2.9.2 contract, and the widget-side
  literals move with them (the assign controller's allowed-slugs lookup and the group caption
  case). This keeps the one real fix the rename carried — widget custom fields were broken
  2.8.x–2.9.2 exactly because those literals said `'Widget::Main'` while the association scope
  said `'Main'` — with the joint now aligned the other way and pinned end to end. Rows written
  under the prefixed names by master-tracking installs are deliberately abandoned (never
  released). No repair task.
- Both `dependent: :delete_all` options are removed (cop-pinned): the placement hook keeps
  owning teardown (now spec-pinned as complete), and hook-less owners return to 2.9.2's
  leave-definitions behavior.
- CHANGELOG documents the `Widget::Assigned` rollback hazard (M7).

## Capabilities

### New Capabilities

- `meta-scope-resolution`: the demodulized `object_class` naming contract, including the
  agreement between the widget admin surfaces and the association scopes.
- `custom-field-definition-lifecycle`: the placement hook owns complete teardown on owner
  destroy; hook-less owners do not cascade definitions.

### Modified Capabilities

None.

## Impact

- `app/models/concerns/camaleon_cms/common_relationships.rb`,
  `app/controllers/camaleon_cms/admin/appearances/widgets/assign_controller.rb`,
  `app/models/camaleon_cms/custom_field_group.rb` (caption case), `CHANGELOG.md`.
- Specs: new `spec/models/meta_scope_resolution_spec.rb`,
  `spec/requests/admin/widget_field_values_spec.rb`,
  `spec/models/custom_field_definition_lifecycle_spec.rb`; two security-spec fixtures follow the
  scope naming.
- No routes or schema changes; no rake task. Master-tracking installs lose rows written under
  the short-lived prefixed scopes (accepted — unreleased).
