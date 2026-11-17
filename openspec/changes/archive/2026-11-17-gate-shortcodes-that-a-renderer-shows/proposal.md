## Why

The `content_shortcodes` gate scans the stored text of a value. But two renderers change the text before they give it to `do_shortcode`:

- `String#translate` removes the translation marker of a later line. So the second line of `<!--:en-->Note` and `[data<!--:en--> field='secret']<!--:-->` shows `[data field='secret']`. Post content, a taxonomy description and a custom field value are translated.
- `the_json_field`, `the_json_fields` and `the_fields_grouped` with JSON parse a custom field value. They give the text of each member to `do_shortcode`. A JSON escape of a bracket shows a bracket there. A member that is an object or an array shows as Ruby text on one line.

So a role without `content_shortcodes` can save a shortcode that runs at render. `spec/requests/security/shortcode_hidden_from_gate_spec.rb` reproduces it.

## What Changes

- The gate scans each text that a renderer gives to `do_shortcode`: the stored text and each translation of it.
- A custom field value can parse as a JSON object. Then the gate also scans the text of each member and each translation of that text.
- A value with no registered shortcode in these texts is stored as before.

Non-goals:

- No change of a renderer or of the stored text. The remedy rule of `docs/security/permissions.md` forbids it.
- No scan of the text that a `post_the_content` or `taxonomy_the_content` hook gives. A hook is the code of a plugin or a theme.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `content-shortcode-gating`: the gate scans each text that a renderer gives to `do_shortcode`, not only the stored text.

## Impact

- `app/models/concerns/camaleon_cms/content_shortcode_gate.rb`: `cama_shortcode_attr_gated?` and the new `cama_shortcode_texts`.
- `app/models/camaleon_cms/custom_fields_relationship.rb`: the texts of the JSON members of a value.
- Specs: `spec/requests/security/shortcode_hidden_from_gate_spec.rb` and `spec/models/content_shortcode_gating_spec.rb`.
- Docs: `CHANGELOG.md`.
