# Proposal: fix-1173-fallout-batch

## Why

PR #1173 (native Rails STI for taxonomies and posts) shipped with no changelog entry and, per the
`2.9.2..master` regression audit, introduced the largest cluster of unresolved high-severity
regressions: existing rows with non-built-in discriminator values now raise
`ActiveRecord::SubclassNotFound` on read *and* create (audit H8); deleting a user orphans their
comments — the anonymous-user reassignment became dead code — and hard-destroys their widgets
(audit H9); and several `inverse_of` declarations name associations that do not exist or point at
the wrong association, so `.owner` raises `InverseOfAssociationNotFoundError` for external
callers and association-loaded records return wrongly-typed navigation targets.

## What Changes

- `TermTaxonomy.find_sti_class` and `PostDefault.find_sti_class` fall back to the STI root
  (`base_class`) for unknown discriminator values instead of raising, restoring 2.9.2's tolerance
  for custom taxonomy/post-class rows on both the read and write paths. A resolution that names a
  non-descendant class is treated as unknown rather than instantiated.
- User deletion reassigns the deleted user's comments to the site's anonymous user again
  (`dependent: :nullify` is removed from `all_comments`, reviving `after_destroy
  :reassign_comments`), and no longer destroys the user's widgets (`dependent: :destroy` removed
  from the built-in user's `widgets` association). `all_posts`' `dependent: :nullify` is kept —
  it only affects the no-surviving-admin case, where 2.9.2 left dangling ids.
- `PostCommentDecorator` tolerates a missing comment author (nil-safe `the_user`,
  `the_author_name`, `the_author_email`) so rows orphaned while the regression was live render
  instead of raising, and a repair task
  (`rake camaleon_cms:reassign_orphaned_comments`) reassigns them to each site's anonymous user.
- Wrong `inverse_of` declarations are corrected: `owner` on `TermTaxonomy`, `PostType`,
  `PostTag`, and `Widget::Main` becomes `inverse_of: false` (the named user-side associations do
  not exist — on any user model for the first three, on custom `user_model` classes for the
  widget); `Site#nav_menu_items` becomes `inverse_of: false` (it loads by `term_group` but
  poisoned the `parent_id`-based `NavMenuItem#parent`, which made the admin menu-item
  custom-fields form show every site field group); `Post#drafts` gets the correct
  `inverse_of: :parent`.

None are breaking: every item restores 2.9.2-observable behavior or fixes association metadata
that could only raise or mislead.

## Capabilities

### New Capabilities

- `sti-discriminator-compatibility`: how unknown or foreign discriminator values in the
  `term_taxonomy.taxonomy` and `posts.post_class` columns are instantiated.
- `user-deletion-content-reassignment`: what happens to a deleted user's comments, posts, and
  widgets, including the repair path for orphaned comments.
- `association-target-integrity`: association traversals return correctly-typed targets and never
  raise for valid data (`owner` readers, `site.nav_menu_items` → `item.parent`,
  `post.drafts` → `draft.owner`).

### Modified Capabilities

<!-- none — no existing capability's requirements change -->

## Impact

- `app/models/camaleon_cms/term_taxonomy.rb`, `post_default.rb` (STI resolution)
- `app/models/concerns/camaleon_cms/user_methods.rb`, `app/models/camaleon_cms/user.rb`
  (deletion behavior), `app/decorators/camaleon_cms/post_comment_decorator.rb` (nil safety)
- `app/models/camaleon_cms/{term_taxonomy,post_type,post_tag,post,site}.rb`,
  `app/models/camaleon_cms/widget/main.rb` (`inverse_of` corrections)
- New `lib/tasks/orphaned_comments.rake`
- Model and lib specs covering each restored behavior
