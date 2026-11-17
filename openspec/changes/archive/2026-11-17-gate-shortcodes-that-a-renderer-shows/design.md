## Context

See `proposal.md`, "Why". `ContentShortcodeGate` validates `Post#content`, `TermTaxonomy#description` and `CustomFieldsRelationship#value`. Before this change, it asked `ShortcodeRegistry.content_has_shortcode?` about the stored text only. Its comment said that the stored text holds each locale, so the scan finds a shortcode in each locale. That is false. `String#split_locales` removes the marker of the locale from each line of a translation, not only from the first line.

## Decisions

**D1. The gate scans each text that a renderer gives to `do_shortcode`.** `cama_shortcode_texts(attr, text)` returns these texts. The concern gives the stored text and each value of `String#translations`. `translate` gives the text itself, the text of one locale or an empty String.

- Alternative: refuse a translation marker that is not at the start of a line. It is a second rule, and it does not cover the JSON members. Rejected.
- Alternative: change `split_locales` to remove only the first marker. It changes what a renderer shows for a translated value of each install. Rejected for this change.

**D2. A custom field value adds the texts of its JSON members.** `CustomFieldsRelationship` overrides `cama_shortcode_texts` for `value`. When the value parses as a JSON object, it adds the `to_s` of each member and each translation of that text. `parse_html_json` of `CustomFieldsConcern` gives the same texts to `do_shortcode`. The parse runs for a value of each kind, because a theme can call `the_json_field` for each field.

- A value that does not parse, or that parses to another type, adds no text. `parse_html_json` raises an error for it, so no shortcode runs.
- Alternative: scan the decoded strings of the parse. The Ruby text of an object member joins two strings on one line. A line break of the stored text can keep the two strings apart. Rejected.

**D3. The gate reads the translations of a copy.** `String#translations` keeps its result on its receiver. `String.new` gives a copy, so the attribute value keeps no result that a later change in place makes wrong.

## Risks / Trade-offs

- [A value that shows a registered shortcode only after a translation or a JSON parse is now refused for a role without `content_shortcodes`.] → Such a stored text is not a form that the admin forms write. An administrator and a holder of the permission store it as before.
- [The gate parses each changed custom field value as JSON at save.] → A value that is not JSON fails the parse at its first character.

## Migration Plan

No data migration. Stored values do not change, and an unchanged value is not checked again.
