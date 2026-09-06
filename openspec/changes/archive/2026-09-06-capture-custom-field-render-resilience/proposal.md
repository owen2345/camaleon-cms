# Capture the custom-field edit-form and settings-save invariants fixed in #1288

## Why

PR [#1288](https://github.com/owen2345/camaleon-cms/pull/1288) fixed a data-loss bug — one custom
field's bad stored value aborted the admin edit form's field rendering, and saving the record in
that state blanked every unrendered field's stored value — and, alongside it, the settings save
that silently discarded the per-kind field options. Both invariants shipped with tests but with
no OpenSpec capability, so the behaviors the tests pin are recorded nowhere durable. This change
captures them; it introduces no code.

## What Changes

- Add `custom-field-render-resilience`: the admin edit form renders each custom field
  independently, so a field with a bad value or a broken render callback degrades alone and the
  fields after it keep their stored values; the colorpicker field accepts any stored value as
  text, keeps its default when unset, does not rewrite the field when opened untouched, and
  survives themed markup and unknown colour formats; option-valued fields (checkbox, checkboxes,
  radio) match stored values as text rather than by selector; a disabled field renders read-only;
  the admin translation decoder accepts typed values.
- Add `custom-field-option-persistence`: saving a custom-field group keeps every per-kind extra
  option the settings panels offer, and deliberately does not accept the `select_eval` field's
  `command` option from the request.
- No application code changes. The behaviors are already on `master` (unreleased 2.9.5) and are
  covered by `spec/features/admin/custom_field_colorpicker_spec.rb` and
  `spec/requests/admin/settings/custom_field_extra_options_spec.rb`.

## Capabilities

### New Capabilities

- `custom-field-render-resilience`: what the admin edit form guarantees when it renders a
  record's custom fields — per-field failure isolation, the colorpicker's value handling, option
  matching for choice fields, the disabled option, and the translation decoder's input types.
- `custom-field-option-persistence`: what a custom-field group save stores for each field's
  per-kind options, and the one option it refuses.

### Modified Capabilities

None. The existing custom-field capabilities cover other layers: `custom-field-value-rejection`
and `custom-field-value-filtering` govern what a value save accepts, `custom-field-list-write-safety`
the list endpoint, `custom-field-definition-lifecycle` teardown, `custom-field-group-tenancy` and
`custom-field-group-placement` group scoping, and `custom-field-sort-ordering` the sort clause.
None of them states what the edit form renders or what a definition save keeps.

## Impact

- **Specs (new):** `openspec/specs/custom-field-render-resilience/spec.md` and
  `openspec/specs/custom-field-option-persistence/spec.md` via this change's deltas.
- **Application code:** none. Referenced but not modified:
  `app/assets/javascripts/camaleon_cms/admin/_custom_fields.js`,
  `app/assets/javascripts/camaleon_cms/admin/bootstrap-colorpicker.js`,
  `app/assets/javascripts/camaleon_cms/admin/_translator.js`,
  `app/controllers/camaleon_cms/admin/settings/custom_fields_controller.rb`.
- **Tests:** none added; the two spec files from #1288 already exercise every scenario except the
  `command` exclusion, which the permit list implements and the design records.
- **Behavior:** unchanged. Documentation plus the changelog entry only.
