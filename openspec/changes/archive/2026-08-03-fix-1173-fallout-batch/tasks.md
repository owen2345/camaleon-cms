# Tasks: fix-1173-fallout-batch

## 1. Red specs

- [x] 1.1 STI compatibility specs: custom `taxonomy` row read/create, unknown `post_class` row
  read, built-in subclass resolution unchanged, non-descendant value loads as root
- [x] 1.2 User-deletion specs: comment reassigned to anonymous user, widget survives, posts to
  surviving admin; decorator nil-safety; orphaned-comments rake task spec
- [x] 1.3 Association-integrity specs: `owner` readers do not raise and return the user;
  `site.nav_menu_items` item keeps its `NavMenu` parent; `post.drafts` draft keeps its author

## 2. Implementation

- [x] 2.1 `TermTaxonomy.find_sti_class`: descendant guard + `base_class` fallback;
  `PostDefault.find_sti_class`: `base_class` fallback after `super`
- [x] 2.2 Remove `dependent: :nullify` from `all_comments`; remove `dependent: :destroy` from
  the built-in user's `widgets`; nil-safe `PostCommentDecorator` readers; add
  `lib/tasks/orphaned_comments.rake`
- [x] 2.3 `inverse_of: false` on `owner` (TermTaxonomy, PostType, PostTag, Widget::Main) and
  `Site#nav_menu_items`; `inverse_of: :parent` on `Post#drafts`

## 3. Verification and close-out

- [x] 3.1 Red→green demonstrated; full gates: `bin/rspec`, `bin/rubocop`,
  `bin/brakeman --no-pager`, `(cd spec/dummy && bin/rails zeitwerk:check)`
- [x] 3.2 PR opened; changelog entry (documents the #1173 fallout and the repair task)
- [x] 3.3 Archive this change on the branch as part of the PR
