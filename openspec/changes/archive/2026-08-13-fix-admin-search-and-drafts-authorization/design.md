# Design

## D1. Search: scope by what the caller may manage

`AdminController` authorizes only login, and `search` is generic over four kinds, so there is no single
`authorize!` subject. The fix instead scopes each kind to the caller's authorized post types — the same
`can? :posts, post_type` decision the admin sidebar already uses to decide which post types to show:

- `cama_admin_searchable_post_type_ids` — the ids of post types the caller may list. For an admin,
  `can? :manage, :all` makes this every type, so search is unchanged for them.
- `post_type` / `category` / `tag` kinds filter to those ids (`where(id:)` / `where(parent_id:)`).
- `content` uses `cama_admin_searchable_posts`, which limits to posts in those post types, and — for a
  non-admin — further to the caller's own posts on any type where they lack `edit_other`, exactly the
  visibility `PostsController#index` applies. So the search cannot surface content the caller could not
  already see in the listing.

A caller with no content permissions gets an empty post-type-id set, so every kind returns nothing —
closing the client enumeration without a special-case.

## D2. Why scoping is the right authorization

The leak was unpublished titles/slugs reaching users who cannot see that content. Rather than bolt on a
coarse status filter (which would also hide content from users entitled to it, e.g. a post type's own
editor searching drafts), the fix ties visibility to the existing per-post-type permission model. The
status-agnostic search is then safe because the *audience* is scoped: you only ever see statuses within
post types you may manage.

## D3. Drafts index

`Posts::DraftsController#index` merely `render json: @post_type` with no check. `@post_type` is already
set by the inherited `set_post_type` before-action, so the fix is a one-line `authorize! :posts,
@post_type` — the same gate `PostsController#index` uses. An unauthorized caller is turned away by the
controller's existing `rescue_from CanCan::AccessDenied` (a dashboard redirect), not a JSON body.

## D4. Testing

`spec/requests/security/admin_search_authorization_spec.rb`: a `client` searching content does not see a
`pending` post's title (fails on master), and their drafts index redirects rather than returning `200`
JSON (fails on master); an `admin` still sees the content and reaches the drafts index (guards against
over-restriction).
