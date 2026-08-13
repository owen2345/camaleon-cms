# Gate field_attrs values at save and render them verbatim

## Why

Follow-up to M17, in the same partial: the `field_attrs` branch rendered
`raw("<strong>#{post['attr']}: </strong>#{post['attr']}")` over JSON parsed from the stored,
attacker-settable field value — a second stored-XSS sink, which also printed the attribute name
twice and never the value. An interim fix escaped the output; under the scan-and-reject policy
(maintainer decision) the remedy is the save gate instead: escaping is a transform of what the
author wrote, and the policy is that stored content either equals authored content or is refused.

### Triage verdict: legit

Reproduced in `spec/models/custom_field_value_rejection_spec.rb` (field_attrs describe) and
`spec/views/render_custom_field_field_attrs_spec.rb`: without the gate a script member is stored,
and the original partial renders the label twice (stash-verified failures).

## What Changes

- `field_attrs` joins the gated positions in `CustomFieldsRelationship`
  (`JSON_MARKUP_FIELD_KEYS`): the gate parses the stored JSON and scans each **decoded** member
  with the markup gate — not the stored bytes, because the Rails JSON encoder unicode-escapes
  angle brackets (`escape_html_entities_in_json`), so a byte-level scan would pass markup that
  `JSON.parse` restores at render. Unparseable values are scanned as-is. Trust, fail-closed and
  opt-out semantics are the shared ones from M17.
- The partial renders the stored attr/value pair verbatim (`raw`), and now renders the pair's
  VALUE (the old line printed the attribute name twice).

## Out of scope

- Constraining the JSON structure itself (extra keys are scanned like the known ones).
