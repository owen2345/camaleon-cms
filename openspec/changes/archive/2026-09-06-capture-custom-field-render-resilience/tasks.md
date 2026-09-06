## 1. Branch

- [x] 1.1 Create `feature/capture-custom-field-render-resilience` from `master` per AGENTS.md Phase 1

## 2. Behaviors already shipped in #1288 (verification: the named example passes on master)

- [x] 2.1 Per-field failure isolation with a console warning — `spec/features/admin/custom_field_colorpicker_spec.rb` "warns when a render callback breaks instead of dying silently" and "renders the picker, its value and the fields after it despite a non-colour value"
- [x] 2.2 Colorpicker accepts any stored value as text, keeps the default white, preserves `0`, tolerates coercible or missing attributes, themed markup, unknown formats, and repaints on re-render — the remaining colorpicker examples in the same file
- [x] 2.3 An untouched picker writes nothing; a pick is written back — "does not overwrite the stored value when the picker is opened and closed untouched" and "still writes the colour back when one was actually picked"
- [x] 2.4 Choice fields match stored values as text — the radio and checkboxes quote examples
- [x] 2.5 A disabled field renders read-only — "renders a disabled field readonly"
- [x] 2.6 The translation decoder accepts typed values — "decodes a non-string translated value without crashing"
- [x] 2.7 A definition save keeps every offered per-kind option — `spec/requests/admin/settings/custom_field_extra_options_spec.rb`
- [x] 2.8 `command` is not permitted — `permitted_field_options` in `app/controllers/camaleon_cms/admin/settings/custom_fields_controller.rb` (no dedicated example; see design.md)

## 3. Specs

- [x] 3.1 Write the `custom-field-render-resilience` delta spec and verify `openspec validate capture-custom-field-render-resilience --strict` passes
- [x] 3.2 Write the `custom-field-option-persistence` delta spec and verify the same validation passes
- [x] 3.3 Confirm no existing capability needs a MODIFIED delta (proposal "Modified Capabilities")

## 4. Documentation

- [x] 4.1 Add the CHANGELOG.md entry under Unreleased after the PR exists, linking it and stating no behavior change

## 5. Close out

- [x] 5.1 Run `/opsx:verify` and address its findings
- [x] 5.2 Run `/opsx:archive` on the branch before merge: sync both capabilities into `openspec/specs/` and commit the archive in the PR
- [x] 5.3 Open the docs-only PR against `master` with the skip-ci marker on every commit (`docs/ai/workflows.md` Phase 3 rule 1)
