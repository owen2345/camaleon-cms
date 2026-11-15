# Tasks

## 1. The owner lookup

- [x] 1.1 Add examples to `spec/models/camaleon_record_spec.rb`. With a top-level host class of the
  same name, `Post`, `Site`, `Theme`, `Category`, `PostTag`, `PostType`, `NavMenuItem`, `NavMenu`,
  `CustomField`, `CustomFieldGroup` and `User` must resolve to the Camaleon class, and the owner of
  a meta of a post must be that post. Make sure that these examples fail before the fix.
- [x] 1.2 Try the Camaleon class first in `CamaleonRecord.polymorphic_class_for` (D1 to D3).
- [x] 1.3 Give the change in `docs/upgrading-to-2.9.5.md`.

## 2. Verification and shipping

- [x] 2.1 `bin/rubocop -A`, the adjacent specs, `bin/brakeman --no-pager`,
  `(cd spec/dummy && bin/rails zeitwerk:check)`
- [x] 2.2 Add the CHANGELOG entry, archive this change on the branch
