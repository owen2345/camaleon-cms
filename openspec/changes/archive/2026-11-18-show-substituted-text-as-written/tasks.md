# Tasks

## 1. The shortcode renderer

- [x] 1.1 Add the example of two values to `spec/requests/security/data_shortcode_field_markup_spec.rb`, and the examples of the shortcode output to `spec/helpers/short_code_helper_spec.rb`. Make sure that they fail before the fix.
- [x] 1.2 Replace each shortcode at its place in `do_shortcode` and `render_shortcode` (D1, D2, D3). Verify that the specs of 1.1 pass.
- [x] 1.3 Add the requirement of the shortcode output to `text-substitution-integrity`, and the notes to `docs/upgrading-to-2.9.5.md` and `docs/ai/ecosystem.md`.

## 2. `cama_replace_codes`

- [x] 2.1 Add `spec/lib/ext/string_spec.rb` with a value that has a backslash sequence or the text of another code. Make sure that it fails before the fix.
- [x] 2.2 Replace all codes in one pass in `cama_replace_codes`. Verify that the spec of 2.1 passes.
- [x] 2.3 Add the requirement to `text-substitution-integrity`, and the notes to `docs/upgrading-to-2.9.5.md` and `docs/ai/ecosystem.md`.

## 3. The menu container

- [x] 3.1 Add an example of a menu item name with a backslash sequence to `spec/helpers/camaleon_cms/frontend/nav_menu_helper_spec.rb`. Make sure that it fails before the fix.
- [x] 3.2 Put the menu items into the container with no replacement in `draw_menu`. Verify that the spec of 3.1 passes.
- [x] 3.3 Add the requirement to `text-substitution-integrity`, and the note to `docs/upgrading-to-2.9.5.md`.

## 4. Shipping

- [x] 4.1 Add a sentence to the CHANGELOG entry of PR #1345.
- [x] 4.2 `bin/rubocop -A`, then `bin/rspec` with the specs of this change and the adjacent specs, `bin/brakeman --no-pager`, `(cd spec/dummy && bin/rails zeitwerk:check)` and `openspec validate --all --strict`. Archive this change on the branch.
