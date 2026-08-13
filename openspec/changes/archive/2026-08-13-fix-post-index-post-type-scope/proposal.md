## Why

The admin post index (`posts_controller.rb#index`) runs `authorize! :posts, @post_type` for the post
type named in the URL, then builds `@post_type.posts`. But when a taxonomy filter is present
(`?taxonomy=category|post_tag&taxonomy_id=…`) it **replaced** that scope with `cat_owner.posts` /
`tag_owner.posts` — the taxonomy owner's posts, looked up site-wide (`current_site.full_categories` /
`current_site.post_tags`) and not re-scoped to the post type. So a user authorized on post type A could
pass a category or tag id belonging to post type B and list B's posts; with `?s=all` (`no_trash`), in
every status. Audit finding M11.

### Triage verdict: legit

Reproduced in `spec/requests/security/post_index_post_type_scope_spec.rb`: a role with `edit_other` on
A only (so no own-posts filter applies) lists a `pending` post of B by passing B's category id to A's
index. Fails without the fix (stash-verified).

## What Changes

- The taxonomy filter now **intersects** with the authorized post type's posts
  (`posts_all = posts_all.where(id: cat_owner.posts)` / `tag_owner.posts`) instead of replacing the
  scope. A category or tag from another post type yields no posts, closing the cross-post-type leak.
- Legitimate filtering is unchanged: a category/tag of the current post type still narrows the listing
  to that taxonomy's posts (the intersection is a no-op there).

## Notes for upgraders

- None. The admin listing behaves identically for a post type's own categories and tags; only
  cross-post-type taxonomy ids (which never returned meaningful results for a user) stop leaking.

## Out of scope

- The frontend taxonomy/archive listings (this is the admin management index).
- The `authorize!`/role model itself; the fix is a scoping correction, not an authorization change.
