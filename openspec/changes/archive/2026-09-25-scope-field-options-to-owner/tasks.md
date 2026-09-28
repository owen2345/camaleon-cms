# Tasks

## 1. Reproduce first

- [x] 1.1 Add `spec/requests/security/field_options_owner_scope_spec.rb`: for the post type, post,
  draft, category, post tag, site, theme, user and widget assignment saves, a slug registered on the
  record saves and a slug registered only on a sibling record (another post type, another site,
  another widget) is dropped; confirm the sibling slug persists against the unfixed controllers
- [x] 1.2 Add `spec/requests/security/nav_menu_item_field_options_spec.rb`: a value for a group placed
  on the menu as the form does is stored, a slug placed on another menu is dropped; confirm the value
  is dropped against the unfixed controller
- [x] 1.3 Add a helper-level spec for the class-wide default and the `field_groups:` narrowing (a
  class-only call permits a sibling's slug, a call with groups does not)

## 2. The keyword

- [x] 2.1 Add `field_groups:` to `cama_permitted_field_options` and `cama_custom_field_allowed_slugs`
  (D1, D2, D5); the 1.3 spec passes and the existing field-option specs stay green

## 3. Core saves

- [x] 3.1 Pass the rendered groups from the site, theme, post type, post, draft, category, post tag,
  user and widget assignment saves; the 1.1 spec passes
- [x] 3.2 Move the nav menu item save and the external item options to `'NavMenu'` with the item's
  menu groups (D4); update the mass-assignment spec's group placement; the 1.2 spec passes
- [x] 3.3 Pass `@plugin.get_field_groups` in the generator template

## 4. Documentation

- [x] 4.1 Record the hardening and the opt-in in `docs/ai/ecosystem.md` (hardening hazards) and
  `docs/upgrading-to-2.9.5.md` (notes for theme & plugin developers)

## 5. Verification and shipping

- [x] 5.1 `bin/rspec` on the new specs and the adjacent ones (`grep -rln cama_permitted_field_options
  spec/`, the custom-field request and model specs), `bin/rubocop -A` on the touched files,
  `bin/brakeman --no-pager`, `(cd spec/dummy && bin/rails zeitwerk:check)`
- [x] 5.2 Open the PR, add the CHANGELOG entry, archive this change on the branch
