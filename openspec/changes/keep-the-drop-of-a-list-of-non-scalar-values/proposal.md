# Keep the drop of a list of non-scalar values

## Why

The shared permit of the admin custom-field saves drops a `values` list that holds a hash. The
`field_attrs` partial names its inputs `values[][attr]` and `values[][value]`, and Rack reads those
names as such a list. A developer who reads the partial can conclude that a save drops the values of
that field. No form sends that list to a save, and no document says why.

## What Changes

- The requirement says why no admin form submits a list of non-scalars.
- A comment at the filter of the permit marks the drop as intended.
- `docs/ai/ecosystem.md` names the theme field that sends hash values, for a later change of the
  filter.
- No code changes.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `custom-field-value-filtering`: the requirement of the two `values` shapes says why a list of
  non-scalars stays dropped.

## Impact

- No change for a host app, a plugin or a theme.
