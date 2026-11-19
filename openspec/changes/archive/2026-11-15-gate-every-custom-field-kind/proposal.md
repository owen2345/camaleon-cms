## Why

The save of a custom field value scans only the `editor`, `field_attrs` and URL kinds, because the custom field templates escape the other kinds. The `data` shortcode does not escape: `[data field='note']` puts the stored value into the post content, and the theme shows the content with `raw`. So an editor or a contributor without `post_content_unfiltered_html` can store a `<script>` in a `text_box` value. The script runs on each page where an administrator put the shortcode. `spec/requests/security/data_shortcode_field_markup_spec.rb` reproduces it.

## What Changes

- The save of a custom field value scans the value of every field kind for an untrusted author. A kind that is not `editor`, `field_attrs` or a URL kind gets the markup rule of `editor`.
- A URL kind (`url`, `image`, `audio`, `video`, `file`) gets the markup rule as well as the URL rule. The `data` shortcode puts a URL value into the content as markup too.
- A value of any kind that parses as JSON is also scanned by its decoded members and keys, as a `field_attrs` value is. `the_json_field` shows them for a field of any kind.
- A holder of the `settings` or the `custom_fields` permission is trusted for the field values of each owner that is not a post. `docs/security/permissions.md` gives these two permissions the trust of an administrator. A holder of the `theme_settings` permission is trusted for the field values of a theme, which it saves through the theme settings.
- `rake camaleon_cms:security:scan_content` lists a stored value of every kind that the scan refuses, because it uses the same dispatch.
- **BREAKING**: an untrusted author can no longer store markup outside the content allowlist in a field of any kind, `text_box` and `text_area` included. An example is `Fish & Chips <today>`. The save fails with an error that names the field. Stored values do not change.

Non-goals:

- No escape or other change of a value at render. The remedy rule of `docs/security/permissions.md` forbids it.
- No new trust through the permission of another save, such as `categories`, `post_tags`, `nav_menu`, `widgets` or `users`. A role with only such a permission stays scanned.
- No change to the `post_content_unfiltered_html` gate on the fields of a post.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `custom-field-value-rejection`: the scan covers every field kind. The holders of `settings` and `custom_fields` are trusted for the fields of each owner that is not a post. The holders of `theme_settings` are trusted for the fields of a theme.

## Impact

- `app/models/camaleon_cms/custom_fields_relationship.rb`: the dispatch of `gate_rejection_reason`, `reject_untrusted_dangerous_value` and `author_trusted_for_unfiltered_value?`.
- `lib/tasks/unsafe_stored_content.rake`: a comment only. The task already calls `gate_rejection_reason`.
- Specs: `spec/models/custom_field_value_rejection_spec.rb`, `spec/requests/security/data_shortcode_field_markup_spec.rb`, a request spec for the site and theme saves, and the spec of the scan task.
- Docs: `docs/security/permissions.md`, `docs/upgrading-to-2.9.5.md`, `CHANGELOG.md`.
- Plugins and themes: a plugin that saves a field value in a background job or a rake task gets the scan for each kind. It calls `unfiltered_value!` to skip the scan, as it does today for `editor`.
