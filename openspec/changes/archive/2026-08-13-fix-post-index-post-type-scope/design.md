# Design

## D1. Intersect, don't replace

The index already starts from the authorized scope, `@post_type.posts`. The bug was that the taxonomy
branch discarded it (`posts_all = cat_owner.posts`). The minimal, behavior-preserving correction is to
keep the base scope and filter it by the taxonomy:

```ruby
posts_all = posts_all.where(id: cat_owner.posts)   # was: cat_owner.posts
posts_all = posts_all.where(id: tag_owner.posts)   # was: tag_owner.posts
```

`where(id: <relation>)` emits an `id IN (SELECT id …)` subquery, so the result is the intersection of
the post type's posts and the taxonomy's posts. For a taxonomy that belongs to the current post type
this changes nothing (every one of that taxonomy's posts is already in the post type). For a taxonomy
from another post type the intersection is empty, which is exactly the desired outcome.

## D2. Why this is the right layer

The `authorize! :posts, @post_type` check is correct — the flaw was that the query then reached posts
outside `@post_type`. Re-scoping at the query keeps the authorization decision and the data it governs
in agreement, and needs no change to the role model or the category/tag lookups (so child-category
behavior via `full_categories` is preserved). The `cat_owner` / `tag_owner` decorated objects are still
used for the breadcrumbs, so those are unaffected.

## D3. The own-posts filter is not the mitigation

`index` also applies `where(user_id: current_user)` when the caller lacks `edit_other`. That is a
per-user filter, not a per-post-type one: a caller with `edit_other` on their own post type (a normal
grant) bypasses it, and it never scoped by post type. The reproduction uses exactly such a role to show
the leak is real independent of the own-posts filter.

## D4. Testing

`spec/requests/security/post_index_post_type_scope_spec.rb`: a role with `edit_other` on post type A
requests A's index filtered by post type B's category and must not see B's `pending` post (fails on
master); and, as a guard, A's index filtered by A's own category still lists A's post.
