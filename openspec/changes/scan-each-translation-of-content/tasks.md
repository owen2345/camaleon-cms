# Tasks

## 1. The scan

- [x] 1.1 Add `spec/requests/security/markup_translation_join_spec.rb` and the unit examples in
  `spec/lib/camaleon_cms/unsafe_markup_spec.rb`. Make sure that they fail without the fix.
- [x] 1.2 Scan each translation in `UnsafeMarkup.unsafe_html?` (D1).
- [x] 1.3 Say so in `docs/security/permissions.md`.

## 2. Verification and shipping

- [x] 2.1 `bin/rubocop -A`, the adjacent specs, `bin/brakeman --no-pager`,
  `(cd spec/dummy && bin/rails zeitwerk:check)`
- [ ] 2.2 Add the CHANGELOG entry, archive this change on the branch
