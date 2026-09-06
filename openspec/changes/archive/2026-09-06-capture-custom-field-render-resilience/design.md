## Context

The behaviors this change specifies shipped in PR
[#1288](https://github.com/owen2345/camaleon-cms/pull/1288) on `master`, unreleased as of 2.9.5.
See `proposal.md` for the motivation. The implementation sits in four places: the admin
custom-field build loop and its per-kind render callbacks
(`app/assets/javascripts/camaleon_cms/admin/_custom_fields.js`), the bundled colorpicker widget
(`app/assets/javascripts/camaleon_cms/admin/bootstrap-colorpicker.js`, whose constructor, `setValue`,
`hide` and slider handler carry the fix), the translation decoder
(`app/assets/javascripts/camaleon_cms/admin/_translator.js`), and the permit list of
`Admin::Settings::CustomFieldsController#permitted_field_options`.

Constraints:

- The field build runs inside one jQuery-ready handler, so an uncaught throw in any field aborts
  every field and initialiser after it. That is the cascade the render-resilience capability
  exists to forbid.
- The colorpicker reads its colour through jQuery's `data()`, which coerces a numeric-looking
  attribute to a Number at read time, and the widget's colour parser takes only strings. The
  attribute alone cannot fix this; the data cache has to be primed with the string form.
- `custom_field_colorpicker` is a public global that a theme's field markup can name in its
  `data-callback-render` attribute, so its contract is part of the capability.

## Goals / Non-Goals

**Goals:**

- State the per-field isolation guarantee and the colorpicker's value contract as testable
  requirements, so a future edit that reintroduces the cascade fails a spec rather than shipping.
- State what a definition save keeps, and the one option it refuses, so the permit list is
  maintained against a requirement instead of rediscovered per panel.

**Non-Goals:**

- Any change to the shipped behavior, the JavaScript, or the controller.
- Re-specifying value-save gating (`custom-field-value-rejection`,
  `custom-field-value-filtering`) or the other existing custom-field capabilities.
- Repairing records whose sibling values were blanked before the fix; the 2.9.5 upgrade guide
  tells operators which records to review.

## Decisions

**Two capabilities, not one.** Rendering the edit form and saving a definition are different
layers with different tests (a `:js` feature spec, a request spec) and different failure modes
(data loss on the record versus options lost on the definition). One spec would blur which
requirement a future change touches. Alternative considered: folding the option persistence into
`custom-field-definition-lifecycle`; rejected because that capability pins teardown, not what a
save keeps.

**Requirements state the observable contract, the mechanism lives here.** The specs say the
picker accepts any stored value as text and that an untouched picker writes nothing; they do not
name the data-cache priming or the `colorpicked` flag. Those are recorded in Context so the next
maintainer understands why priming the attribute alone regresses, without freezing the mechanism
into the contract.

**Spell out the value shapes.** Everything `data()` coerces — numbers, booleans, `null`, JSON —
crashed identically, so the colorpicker requirement lists the shapes rather than saying "any
value": a fix that handles numbers only would pass a vaguer requirement.

**The `command` exclusion is a requirement, not a comment.** The permit list's comment says
`:command` is deliberately not permitted; the option holds a Ruby expression and `select_eval`
is intentionally left non-working. A persistence requirement that read "keep every offered
option" without the exclusion would invite a well-meaning edit to permit it. The scenario is
implemented by the permit list; it is the one scenario in this change without a dedicated
example, which is acceptable for a documentation-only capture and noted in the proposal.

**Tasks are pre-checked.** The implementation and its tests merged in #1288; this change records
them and is archived on the branch in the same PR (`docs/ai/workflows.md` Phase 4), so `master`
never carries an unarchived completed change.

## Risks / Trade-offs

- **The `command` scenario has no example** → the permit list is the implementation and any
  future edit to it is reviewed against this requirement; a request-spec example can be added
  when the controller is next touched.
- **Scenarios pin widget markup details (addon, icon, colour-format attribute)** → accepted: the
  themed-markup contract is exactly what themes rely on, and the failures were markup-shaped.
- **Warnings instead of errors hide a broken callback from the user** → the console warning names
  the callback, and the alternative (the cascade) blanked stored values; degrading one field is
  the lesser harm and the requirement says so.
