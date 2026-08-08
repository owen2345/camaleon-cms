## 1. M12 — create-only validated post_parent (commit 1)

- [x] 1.1 Repro request specs in `spec/requests/security/draft_authorization_spec.rb`:
      client-supplied `post[post_parent]` with `post_id` absent, and with `post_id` invalid, must
      leave the created draft's `post_parent` nil (red against the pre-fix controller); plus the
      create-only pin — a `PATCH` omitting `post_id` leaves a parented draft's `post_parent`
      unchanged (guards against the unconditional-mirror variant).
- [x] 1.2 In `set_post_data_params`: drop `:post_parent` from the permit list; on create only,
      assign `post_data[:post_parent]` unconditionally from the validated `params[:post_id]`
      (nil otherwise); update builds no `post_parent` at all.
- [x] 1.3 Drafts request spec file green; `bin/rubocop` clean on touched files; commit M12
      (spec + fix).

## 2. M13 — per-user draft buffers (commit 2)

- [x] 2.1 Repro request specs (verified red against master's controller): edit-own-only owner
      autosaves own post while another user's buffer exists → 200, own buffer created, other
      buffer untouched; own buffer reused on next autosave (no third row); `PATCH` on another
      user's draft id → `RecordNotFound`, unchanged; no buffer creation under a post the user
      cannot update (even holding `create_post`); draft ownership grants nothing under another
      user's post; `edit_other`-only role autosaves another's post into its own buffer; edit
      form's view-draft link targets the current user's own buffer when two buffers exist.
- [x] 2.2 `DraftsController`: `create` resolves the validated parent once, authorizes
      `:update` on it (or `:create_post` when parentless), and scopes the buffer lookup by
      (post type, parent, current user); `update` scopes its finder by (post type, current user)
      and authorizes `:update` on `@post_draft.parent || @post_draft`.
- [x] 2.3 `form.html.erb`: view-draft link uses the current user's own buffer instead of
      `@post.drafts.pluck('id')`.
- [x] 2.4 Drafts request spec file green; `bin/rubocop` clean on touched files; commit M13
      (specs + fix).

## 3. Verification and CI parity

- [x] 3.1 Full `bin/rspec` suite green.
- [x] 3.2 `bin/rubocop` clean, `bin/brakeman --no-pager` clean,
      `(cd spec/dummy && bin/rails zeitwerk:check)` clean.

## 4. OpenSpec + PR protocol

- [x] 4.1 `openspec validate fix-draft-autosave-scoping --strict` passes; archive the change
      on-branch (`openspec archive`) syncing the `draft-authorization` deltas; commit the archived
      change as its own commit (no `[skip ci]` — it heads the first push).
- [x] 4.2 Push branch, open the PR (What and Why + User-Visible Impact; no files-changed/test
      counts/logs/SHAs), first push runs CI.
- [x] 4.3 Commit the short changelog entry referencing the PR with `[skip ci]` and push.
