# Tasks

## 1. The tag editor

- [x] 1.1 Add `spec/features/admin/post_tag_markup_spec.rb`. A stored tag name with an `img` tag and
  the `tags` param of a GET link must show as text. An open tag must hold a name with a quote. Make
  sure that the examples fail before the fix.
- [x] 1.2 Read a tag as text and encode the name in the HTML strings of the tag editor (D1, D2).
- [x] 1.3 Give the text form of a tag name in `docs/upgrading-to-2.9.5.md`.

## 2. The permalink line

- [x] 2.1 Add `spec/features/admin/post_slug_markup_spec.rb`. A stored slug with an `img` tag must show
  as text. Make sure that the example fails before the fix.
- [x] 2.2 Set the slug and the URL around it as text in `set_slug` of `_post.js` (D1).
- [x] 2.3 Give the change in `docs/upgrading-to-2.9.5.md`.

## 3. Verification and shipping

- [ ] 3.1 `bin/rubocop -A`, the adjacent specs, `bin/brakeman --no-pager`,
  `(cd spec/dummy && bin/rails zeitwerk:check)`
- [ ] 3.2 Update the CHANGELOG entry and the PR description, archive this change on the branch
