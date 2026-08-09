# Design — fix-namespaced-user-field-scope

## Context

See `proposal.md` — Why. Load-bearing facts verified in code and git history:

- The association scope was `'User'` at every released version: a hardcoded
  `cama_define_common_relationships('User')` literal through 2.6.4, `name.demodulize` since the
  concern refactor shipped in 2.7.0, restored (as `name.to_s.demodulize`) by #1238.
- Two surfaces have carried a qualified name since the v1.0-era codebase:
  `get_user_field_groups` reads `parseCamaClass` (which strips only `Decorator` and
  `CamaleonCms::`, so a host `Admin::User` stays `'Admin::User'`), and the settings form emits
  the raw `user_model` config string as the users placement option.
- Through 2.9.1 this dual naming was harmless: the users controller passed
  `params[:field_options]` to `set_field_values` unfiltered, and values were written and read
  through the `'User'`-scoped association. The 2.9.2 mass-assignment hardening (eba56d6f) keys
  the allowed-slugs lookup on the `'User'` literal, which finds no qualified groups — submitted
  values are silently discarded (same anatomy as the widget joint fixed in #1238).
- User field groups are site-global: placed with `objectid = site.id`, read through
  `site.custom_field_groups` (tenancy scope) plus the placement class name. Values are per-user
  through the association (`objectid = user.id`, `object_class: 'User'`), so no value rows and
  no meta rows were ever written under the qualified name at any released version. Group field
  rows hang off `parent_id` with `object_class: '_fields'`; group metas key off
  `'CustomFieldGroup'`. Only the group placement rows are stranded.
- Zero external consumers: a sweep of the 22 local ecosystem repos found no caller of
  `get_user_field_groups` outside the engine.

## Goals / Non-Goals

**Goals:**

- Every user custom-fields surface (placement emission, user-page read, save filter,
  association) agrees on the demodulized name, per the meta-scope-resolution contract.
- Groups placed under the old qualified emission keep working after one idempotent repair task.
- Zero behavioral change for non-namespaced installs (engine default and top-level host `User`).

**Non-Goals:**

- No compatibility read for qualified names in runtime code (see Decisions).
- No change to the `custom_field_custom_models` hook option emission (`model.name` raw): hook
  models are host-authored, and their groups are read back through the association-scoped
  `get_field_groups` else-arm — a host registering a namespaced hook model has the same joint,
  but its naming is the host's contract, not the engine's user_model config.
- No re-keying of rows written by unreleased master-tracking installs under the short-lived
  prefixed association scopes — already deliberately abandoned by #1238.
- No change to the users controller literal or the association scope: both already say
  `'User'`, which is the pinned contract.

## Decisions

1. **Demodulize at the source, in both qualified surfaces.**
   `get_user_field_groups` becomes `self.class.to_s.parseCamaClass.demodulize` — parseCamaClass
   is kept for its `Decorator` strip, demodulize collapses any namespace. The form option
   becomes `PluginRoutes.get_user_class_name.demodulize` (the canonical accessor; its
   `CamaleonCms::User` default demodulizes to the same `'User'` the old fallback emitted).
   Rejected: a dual-spelling compatibility read (`where(object_class: [qualified, demodulized])`)
   — it manages the divergence forever instead of deleting it, and the save filter would need
   the same widening to actually fix the discard.
2. **Repair task re-keys exactly what the old form emitted.** The task derives the qualified
   name from the `user_model` config (`presence`, mirroring the old emission) and re-keys
   `custom_fields` rows with that exact `object_class` to its demodulized form via one
   `update_all`. Keyed to the current config: it deliberately covers an explicitly configured
   `CamaleonCms::User` (whose groups were equally stranded — placed qualified, read
   demodulized) and is a no-op when the config is blank or already demodulized. A host that
   renamed its user model since writing groups must pass the historical name — documented in
   the task's desc/comment rather than guessed at.
   Rejected: a migration (project convention: backfills are rake tasks); per-row
   `find_each`/`update_column` (the precedent for computed per-row values — this re-key is
   uniform, so a single statement is simpler and naturally idempotent).
3. **Repro-first where the defect reproduces.** The namespaced read (model spec) and the form
   emission (request spec, `static_system_info` stubbed with a merged hash — safe because the
   auth path resolves users through load-time associations and
   `legacy_camaleon_polymorphic_class` uses `safe_constantize`) are proven red against the
   current code. The user round-trip request spec is a green-by-design end-to-end pin, the
   sibling of #1238's widget pin, era-portable against any future one-sided rename.

## Risks / Trade-offs

- [A namespaced-host admin re-saves an old qualified group before running the task] → the
  placement validation admits both spellings (`owned_placement_ids` else-arm keys on the site
  id), and the re-save path preserves a stored placement absent from the select — the group
  stays qualified but intact; the task repairs it whenever it runs.
- [The task's config-derived key misses rows if the host renamed its user model] → stated in
  the task output; the update is a one-liner an operator can re-run with the historical name
  re-keyed through the same task after temporarily restoring the config value.
- [Stubbing `static_system_info` wholesale in specs could destabilize unrelated reads] → the
  stub merges onto the real hash (only `user_model` differs) and is scoped to the examples that
  need it.

## Migration Plan

Code change deploys normally; affected installs (namespaced `user_model` only) run
`bin/rails camaleon_cms:demodulize_user_field_groups` once after deploy. Rollback = revert the
commits. Rollback hazard after the task has run: 2.9.2's qualified reader no longer finds the
re-keyed `'User'` groups, so they disappear from the user edit page until re-upgrade — data
intact, nothing deleted. That is no worse than 2.9.2's steady state (where the groups rendered
but every save was discarded), and it mirrors the documented `Widget::Assigned` hazard.
