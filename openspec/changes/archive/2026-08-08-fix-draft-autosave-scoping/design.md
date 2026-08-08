# Design — fix-draft-autosave-scoping

## Context

See `proposal.md` — Why. Both defects live in
`app/controllers/camaleon_cms/admin/posts/drafts_controller.rb`, introduced by #1196 while adding
authorization to a previously unguarded endpoint. Constraints:

- The CanCan `:update` rule for posts (`CamaleonCms::Ability`) grants edit-own-only roles
  `post.user_id == user.id` — evaluated against whatever object `authorize!` receives.
- The shipped autosave JS (`app/assets/javascripts/camaleon_cms/admin/_post.js`) sends
  `data.post_id` on both create and update, and PATCHes only the draft id it received from its own
  earlier create — no legitimate client re-parents a draft or touches another user's draft.
- Publishing/saving a post destroys all of its buffers (`@post.drafts.destroy_all` on update with
  drafts; `draft_id`-targeted destroy on create), which bounds buffer accumulation.
- Maintainer decision (2026-08-08, supersedes the first draft of this design): a shared per-post
  buffer with parent-post authorization still lets one authorized editor destroy another's
  unpublished work-in-progress; adopt per-user buffers instead, plus create-only `post_parent`.

## Goals / Non-Goals

**Goals**

- `post_parent` mirrors only the *validated* `params[:post_id]` of a create request — never the
  client-writable `post[post_parent]`, and never mutable after creation.
- No user can read, overwrite, re-parent, or detach another user's draft buffer.
- Autosave works for every user entitled to edit the post: edit-own-only owners (M13's lock-out),
  and `edit_other` holders editing someone else's post (a #1196 `:create_post`-only edge).

**Non-Goals**

- No change to how published posts, the posts index/drafts tab, or `PostsController` consume
  drafts (the listing showing one buffer per editing user is an accepted consequence, not a
  redesign of those surfaces).
- No repair/migration for buffers that predate the fix: an existing shared buffer simply remains
  its creator's buffer; other editors get fresh buffers; any successful save still clears all.
- No change to the XHR error format: an `AccessDenied` autosave still receives the admin HTML
  redirect. Making autosave failures visible as JSON is a possible later hardening, out of scope
  here.

## Decisions

1. **`post_parent` is create-only** (assigned unconditionally on create from the validated
   `params[:post_id]`, or nil; update never touches it; `:post_parent` leaves the permit list).
   Alternatives rejected:
   - *Guarded assignment only when the param is valid* — that is exactly what created M12: the
     permitted `post[post_parent]` survived the untaken branch.
   - *Unconditional mirror on update too (2.9.2's shape)* — restores a sharp edge where a `PATCH`
     omitting `post_id` detaches the draft; nothing legitimate needs update-time re-parenting.
2. **Per-user buffers, enforced at lookup scope.** `create` finds the draft by (post type, parent
   post, current user); `update` finds by (post type, current user, id). Another user's buffer is
   *unreachable* (`RecordNotFound`), not merely denied — invisibility can't regress into an
   authorization-order bug, and it leaves no oracle about other users' drafts. Alternative
   rejected (maintainer decision): shared slot with `authorize! :update` on the parent — closes
   M13 but keeps cross-user WIP destruction inside the authorized-editor group.
3. **Authorization follows the post being edited.** Validated parent present →
   `authorize! :update, parent` for creating or overwriting the user's own buffer under it (a
   buffer is an artifact of editing that post; permission loss on the post revokes autosave too).
   No parent → `authorize! :create_post, @post_type` (authoring new content). This deliberately
   lets `edit_other`-only roles autosave posts they can edit but not author — fixing that #1196
   edge is a consequence of the principle, pinned by a scenario. The draft row is the authorize
   target only for parentless drafts (their creator).
4. **`user_id` preservation strengthens into per-user ownership.** #1196's "preserve on
   overwrite" requirement was the anti-ownership-theft control; with per-user scoping, cross-user
   overwrite is impossible, so ownership can never change hands — the requirement is restated in
   those terms rather than removed.
5. **The edit form's "view draft" link scopes to the current user's buffer.** The existing
   `@post.drafts.pluck('id')` interpolates an *array* into one URL — already broken the moment a
   post has two drafts (reachable today via M12's collision). With per-user buffers it must be
   the user's own draft: `@post.drafts.where(user_id: cama_current_user.id).first`.
6. **Repro-first request specs** in `spec/requests/security/draft_authorization_spec.rb`, per the
   security-fix testing rule. The M13/per-user positives and the parent-gate negatives must fail
   against the pre-fix controller (verified by running the new specs against a checkout of
   master's controller); the create-only `post_parent` pin (update keeps its parent) guards the
   fix's shape — master passes it, the naive unconditional-mirror variant fails it, which is the
   point.

## Risks / Trade-offs

- [Admin drafts listing shows one buffer per editing user per post; abandoned buffers linger
  until the post is next saved] → Bounded by `drafts.destroy_all` on every successful save;
  listing/count changes are cosmetic and documented in the changelog upgrader notes.
- [A pre-fix shared buffer keeps its creator's ownership; the post owner starts a fresh buffer
  and does not see the other editor's pending autosave content] → Same information hiding the
  per-user model prescribes going forward; the old buffer is not lost (visible in the drafts
  listing, cleared on save).
- [Rolling back to 2.9.2 with multiple buffers per post] → 2.9.2's unscoped
  `where(post_parent: X).first` picks one buffer arbitrarily and its autosave overwrites it with
  ownership transfer — the pre-#1196 status quo; extra buffers are cleared on the next successful
  save. No data-shape hazard (plain `draft_child` rows throughout).

## Migration Plan

Code-only; no data or schema changes; no repair task needed. Deploy normally; rollback = revert
the two commits. The behavior delta is confined to the admin drafts XHR endpoint and the edit
form's view-draft link.
