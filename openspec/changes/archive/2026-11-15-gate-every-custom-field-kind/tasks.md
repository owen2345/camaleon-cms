# Tasks

## 1. The scan of every field kind

- [x] 1.1 Keep `spec/requests/security/data_shortcode_field_markup_spec.rb`. Change its examples to expect a refusal with an error that names the field, and no script on the page. Make sure that the editor and contributor examples fail before the fix.
- [x] 1.2 In `spec/models/custom_field_value_rejection_spec.rb`, replace the example "carries no gate for values the renderer escapes". Add examples: a script `text_box` value is refused, `a < b & c` and `<b>bold</b>` are stored unchanged, and a `url` value with `"><script>` is refused. Add the forged-id example of a `text_box` id on a `url` slug. Make sure that the new refusal examples fail before the fix.
- [x] 1.3 In `custom_fields_relationship.rb`, apply D1 to D4: remove `GATED_FIELD_KEYS`, `MARKUP_FIELD_KEYS`, `gated_field_key?` and the early return, and give a URL kind both rules. Update the comments. Verify that the specs of 1.1 and 1.2 pass.
- [x] 1.4 In `spec/lib/tasks/unsafe_stored_content_rake_spec.rb`, add an example: the task lists a stored `text_box` value with a script. Update the comment above the custom field loop of `lib/tasks/unsafe_stored_content.rake`. Verify that the example passes.

## 2. The trust of site and theme field values

- [x] 2.1 Add request examples for D5 under `spec/requests/security/`. A role with `settings` stores a script `text_box` site field value through the site settings save. A role with `theme_settings` stores one through the theme settings save. Make sure that the two examples fail before the fix.
- [x] 2.2 Add model examples to `spec/models/custom_field_value_rejection_spec.rb`. A role with `settings` and no `theme_settings` is refused a script theme field value. The authorization of the theme save stops such a role before the scan, so only a model example reaches the check. A role with `settings` and `theme_settings` is refused a script category field value. With no request context, a script site or theme field value is refused.
- [x] 2.3 Extend `author_trusted_for_unfiltered_value?` for a `CamaleonCms::Site` and a `CamaleonCms::Theme` owner (D5). Verify that the specs of 2.1 and 2.2 pass.
- [x] 2.4 Trust a holder of `settings` or `custom_fields` for the fields of each owner that is not a post (D5). Change the model examples of 2.2: such a role stores a script theme and category field value, and is refused a script post field value. A role with only `theme_settings` is refused a script site or category field value.

## 3. Docs

- [x] 3.1 Update `docs/security/permissions.md`: the scan covers every field kind, and the trust of the site and theme field values. Run the Markdown gate of `docs/ai/prose.md` on the staged files.
- [x] 3.2 Add the upgrade note to `docs/upgrading-to-2.9.5.md`: what an untrusted author can no longer store, and the `scan_content` task.

## 4. Verification and shipping

- [x] 4.1 `bin/rubocop -A`, then `bin/rspec` with the specs of this change and the adjacent specs (`docs/ai/testing.md`, "Which specs to run"), `bin/brakeman --no-pager`, `(cd spec/dummy && bin/rails zeitwerk:check)`, `openspec validate --all --strict`.
- [x] 4.2 Add the CHANGELOG entry after the PR exists, and archive this change on the branch.
