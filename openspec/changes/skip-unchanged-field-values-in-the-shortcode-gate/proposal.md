# Skip an unchanged custom field value in the shortcode gate

## Why

The admin form of a post sends each stored custom field value again. `set_field_values` deletes the
value rows and creates them again, so each row is a new record. The `content_shortcodes` gate
checked each new record. A field value can hold a shortcode that an administrator wrote. Then
an editor without `content_shortcodes` could not save the post, also with only a title change.

The markup gate already skips such a value. Post content and a taxonomy description are checked
only when they change.

## What Changes

- `set_field_values` marks a new row whose slug and value equal a stored row with
  `previously_stored!`.
- The `content_shortcodes` gate and the markup gate skip a marked row.
- `unfiltered_value!` is again only the opt-out of trusted server code.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `content-shortcode-gating`: an unchanged custom field value is not checked again.

## Impact

- `CustomFieldsRead#set_field_values`, `CustomFieldsRelationship` and `ContentShortcodeGate`.
- A changed value with a shortcode is refused as before.
