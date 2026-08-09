# Proposal — fix-namespaced-user-field-scope

## Why

For a host app that configures a namespaced user model (`user_model: 'Admin::User'`), the user
custom-fields feature silently discards every submitted value since 2.9.2: the settings form
places groups under the raw qualified name and the user edit page reads them back the same way,
but the save filter and the association scope both use the demodulized `'User'` — so the
allowed-slugs lookup comes back empty (regression audit N5). The demodulized contract was just
pinned by the `meta-scope-resolution` capability (PR #1238); these two surfaces still contradict
it.

## What Changes

- `CustomFieldsRead#get_user_field_groups` derives its placement query from the demodulized
  class name (keeping the `Decorator` strip), matching the association scope.
- The custom-fields settings form emits the demodulized user-model name in the users placement
  option, so new groups are stored under the name every other surface reads.
- A new idempotent rake task re-keys group placements stored under the previously emitted
  qualified name to the demodulized contract, so existing groups survive the read-side change.
- Installs on the engine-default `CamaleonCms::User` or a top-level host `User` see no
  behavioral change (all spellings already collapse to `'User'`).

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `meta-scope-resolution`: the "surfaces agree with the scope names" contract extends beyond the
  widget admin to the user custom-fields surfaces (placement emission, user-page read), and
  gains a repair-task requirement for legacy qualified placements.

## Impact

- `app/models/concerns/camaleon_cms/custom_fields_read.rb` (`get_user_field_groups`)
- `app/views/camaleon_cms/admin/settings/custom_fields/form.html.erb` (users placement option)
- `lib/tasks/user_field_groups.rake` (new repair task) + task spec
- Specs: `spec/models/meta_scope_resolution_spec.rb`, a new settings-form request spec, a new
  user field-values round-trip request spec
- No migration; no change for non-namespaced installs; no API removal (ecosystem sweep found
  zero external `get_user_field_groups` consumers)
