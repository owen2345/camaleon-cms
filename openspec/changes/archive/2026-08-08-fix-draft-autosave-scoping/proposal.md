## Why

The 2026-08 regression audit (findings M12 and M13, `REGRESSION-AUDIT-2026-08-03.md`) confirmed two
defects that #1196 introduced into the draft autosave endpoint while fixing its missing
authorization:

- **M12** — `set_post_data_params` assigns `post_parent` only when `params[:post_id]` is present
  and resolves to a real post, but `:post_parent` is also in the strong-parameters permit list. A
  client-supplied `post[post_parent]` therefore survives unvalidated on every new-post autosave
  (2.9.2 overwrote it unconditionally). A forged value parents the "new" draft under an arbitrary
  existing post, where it collides with that post's draft slot (overwrite on next autosave,
  `drafts.destroy_all` on update, stale `post_draft_id` → `RecordNotFound`). The existing
  `draft-authorization` scenarios "post_parent nil for invalid post / when post_id absent" pass
  only because they never smuggle the parameter — they are vacuous against this hole.
- **M13** — both `authorize! :update` calls target the draft row itself. Since #1196 also
  (correctly) froze `user_id` to the draft's creator, the CanCan `:update` rule for edit-own-only
  roles (`post.user_id == user.id`) now checks the *draft creator* instead of the *post being
  edited*. A user whose own post carries a draft created by someone else (e.g. an admin edited it
  once) gets `CanCan::AccessDenied` on every autosave of their own post — the XHR receives an
  HTML redirect and autosave silently stops.

The maintainer reviewed the initially proposed fix (shared draft slot, authorization retargeted to
the parent post) and directed a stronger resolution: as long as a single buffer is shared per
post, *some* authorized user can destroy another editor's unpublished work-in-progress. Draft
buffers therefore become **per-user**, eliminating cross-user draft access entirely instead of
re-scoping it.

## What Changes

- **`post_parent` is create-only and never client-writable.** `set_post_data_params` drops
  `:post_parent` from the permit list; on create it assigns the validated `params[:post_id]`
  (a post existing in the current site) or nil, unconditionally; update never modifies
  `post_parent` at all. A forged `PATCH` can no longer detach a draft from its post, and a forged
  `POST` can no longer parent a draft under an arbitrary post.
- **Draft buffers are per-user.** `create` looks up the draft scoped by post type, parent post,
  **and current user**; `update`'s finder is scoped to the current user's drafts, so another
  user's buffer is unreachable (`RecordNotFound`), not merely denied. No user can read, overwrite,
  or detach another user's autosave buffer.
- **Authorization follows the post being edited.** Creating or overwriting a buffer under an
  existing post requires `authorize! :update` on that post; a parentless (new-post) buffer
  requires `:create_post` on the post type. Consequently a role holding only `edit_other` can now
  autosave while editing another user's post (its first autosave was denied under #1196's
  `:create_post`-only rule), and a role that lost update rights on a post loses autosave there
  too.
- **The edit form's "view draft" link targets the current user's own buffer** (the existing
  `@post.drafts.pluck('id')` produced a broken multi-id URL the moment a post had more than one
  draft).
- `user_id` semantics: new buffers stamp the current user; overwrites only ever touch the current
  user's own buffer, so draft ownership never changes hands (strengthens #1196's preservation
  requirement from "preserved on cross-user overwrite" to "cross-user overwrite impossible").

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `draft-authorization`: lookup requirements for create and update gain per-user scoping; the
  authorization requirements re-target `authorize!` from the draft row to the parent post
  (`:create_post` only for parentless buffers); the user_id-preservation requirement becomes the
  per-user ownership contract; the `post_parent` requirement becomes create-only, validated,
  never client-writable; a new requirement pins per-user buffer isolation (including the
  own-buffer "view draft" link).

## Impact

- `app/controllers/camaleon_cms/admin/posts/drafts_controller.rb` (`create`, `update`,
  `set_post_data_params`).
- `app/views/camaleon_cms/admin/posts/form.html.erb` (view-draft link).
- `spec/requests/security/draft_authorization_spec.rb` gains repro coverage for both findings and
  the per-user isolation contract.
- No route, model, JS, or schema changes; no migration. Pre-existing shared buffers keep working:
  they remain their creator's buffer, other editors get fresh buffers on next autosave, and any
  successful save of the post still destroys all of its buffers (`drafts.destroy_all`).
- Admin-visible behavior change: the drafts listing can show one buffer per editing user per post
  (previously exactly one shared buffer per post).
