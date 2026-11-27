# Record the text editor rules of a custom field sort

## Why

PR #1370 changed how a sort of custom fields treats the TinyMCE text editors of the dragged item. It
also changed how a new text editor field gets its id. The PR shipped without OpenSpec requirements,
so no spec holds these rules.

An admin can drag a repeatable field group, or a value of a field that takes more than one value. A
text editor does not survive a move of its panel in the page. For this reason, Camaleon removes the
text editors of the dragged item, and sets them up again at the drop.

## What Changes

- A new capability records the rules that PR #1370 put in place. The code does not change.

## Capabilities

### New Capabilities

- `custom-field-text-editor-sort`: a drag of a field group or of a field value sets up each text
  editor of the item again. Each text editor keeps its own settings. An inline text editor stays. A new text
  editor field gets an id that no element and no text editor of the page has.

### Modified Capabilities

None.

## Impact

- `app/assets/javascripts/camaleon_cms/admin/_custom_fields.js` holds the rules. The specs are
  `spec/features/admin/custom_field_editor_sort_spec.rb` and
  `spec/features/admin/custom_field_editor_id_spec.rb`.
