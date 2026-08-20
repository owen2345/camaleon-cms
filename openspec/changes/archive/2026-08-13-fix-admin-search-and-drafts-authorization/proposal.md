## Why

Two admin endpoints ran with no authorization. `AdminController#search` queried `current_site.posts`
with no status filter and no permission check, so any admin-area user — including a `client` with no
content rights — could enumerate every post's title and slug in every status (draft, pending, private,
trash), plus post types, categories and tags they cannot manage. `Posts::DraftsController#index`
rendered the post type as JSON with no `authorize!` call at all. Audit finding M12.

### Triage verdict: legit

`AdminController` gates only on `cama_authenticate` (login), with no per-action capability check, so a
`client` reaches both actions. Reproduced in `spec/requests/security/admin_search_authorization_spec.rb`:
a client's content search lists a `pending` post's title, and the drafts index returns `200` JSON —
both fail without the fix (stash-verified).

## What Changes

- `search` scopes every kind to the post types the caller may manage (`can? :posts`): post
  types/categories/tags are filtered to those types, and content is limited to posts in accessible post
  types, further restricted to the caller's own posts on types where they lack `edit_other` (mirroring
  `PostsController#index`). Admins (`can :manage, :all`) still search everything.
- `DraftsController#index` now runs `authorize! :posts, @post_type`, matching the post listing.

## Notes for upgraders

- None for authorized users. An admin-area user with no content permissions no longer sees content,
  post types, categories or tags in the global search, and can no longer read a post type's JSON via
  the drafts index.

## Out of scope

- The frontend search (`spec/requests/frontend/search_spec.rb`), which is a separate path.
- Broader admin-search UX (pagination, ranking) — unchanged.
