## Context

`DraftsController` inherits from `PostsController` but overrides `create` and `update` without calling `authorize!` or scoping queries to `@post_type`. The parent controller (`PostsController`) calls `authorize!` on every mutating action — the override breaks the chain.

The `create` action uses a global `CamaleonCms::Post.drafts.where(post_parent: ...)` lookup that ignores post type and user ownership. If a draft exists for the given `post_parent`, it overwrites it without checking authorization. If no draft exists, it creates one under `@post_type.posts.new(...)` but sets `post_parent` from `params[:post_id]` without validation.

The `update` action uses `CamaleonCms::Post.drafts.find(params[:id])` — completely global, no scoping at all.

The `set_post_data_params` before_action (shared by both actions) unconditionally sets `user_id` to `cama_current_user.id`, allowing ownership theft on existing drafts.

## Goals / Non-Goals

**Goals:**
- Draft lookups scoped to `@post_type` in both `create` and `update`
- `authorize!` calls before any draft mutation, matching `PostsController` patterns
- `user_id` only set on genuinely new drafts, not when overwriting existing ones
- `post_parent` validated against a real post
- Request specs proving authorized/unauthorized access behavior

**Non-Goals:**
- Refactoring the draft promotion logic in `PostsController#update`
- Adding draft authorization to the frontend `draft_render` (already correctly gated via `can?`)
- Fixing `ThemesAdminController` (deferred)
- Adding role management UI changes
- Changing the autosave JavaScript

## Decisions

### Decision 1: Scope draft lookups to `@post_type` instead of global `Post`

**Chosen:** `@post_type.posts.drafts.find(...)` and `@post_type.posts.drafts.where(post_parent: ...)`

**Rationale:** The route already includes `post_type_id`. The parent controller sets `@post_type` via `set_post_type` before_action. Scoping to `@post_type` ensures an attacker with access to one post type cannot reach drafts in another. This matches how `PostsController` does all its lookups (`@post_type.posts.find`, `@post_type.posts.new`).

**Alternatives considered:**
- `current_site.posts.drafts.where(...)` — site-scoped but not post-type-scoped. Weaker isolation.
- User-scoped (`where(user_id: cama_current_user.id)`) — too restrictive; editors with `edit_other` need to see other users' drafts.

### Decision 2: Add `authorize!` with existing ability rules

| Action | Mutation path | Authorization check |
|--------|--------------|-------------------|
| `create` | Overwriting existing draft | `authorize! :update, @post_draft` |
| `create` | Creating new draft | `authorize! :create_post, @post_type` |
| `update` | Updating draft by ID | `authorize! :update, @post_draft` |

**Rationale:** These are the same rules used by `PostsController#create` and `PostsController#update`. The `Ability` class already defines `:update` on `CamaleonCms::Post` (checking user_id, edit_other, edit_publish) and `:create_post` on `CamaleonCms::PostType`. No new ability definitions needed.

### Decision 3: User ID only set on genuinely new records

**Chosen:** Remove `post_data[:user_id]` from `set_post_data_params`. In `create`, set `@post_draft.user_id = cama_current_user.id` only on the new-record branch (line 19). The existing-draft-overwrite branch (line 13-17) keeps the original `user_id`.

**Rationale:** Prevents ownership theft. An attacker who overwrites an existing draft should not become its owner — the original creator's `user_id` is preserved. A new draft created from scratch should belong to the current user.

### Decision 4: Validate `post_parent` references a real post

**Chosen:** In `set_post_data_params`, only set `post_parent` if `params[:post_id]` is present AND references an existing post within `current_site`. If the post doesn't exist, treat `post_parent` as nil.

**Rationale:** Prevents orphaned draft associations. This is a data integrity check, not authorization — the authorization is handled by `authorize!` separately.

## Risks / Trade-offs

- **[Risk] Backward compatibility for plugins hooking into draft events**: Plugins that hook `create_post_draft` / `created_post_draft` / `update_post_draft` / `updated_post_draft` may now receive `authorize!` denials. → **Mitigation**: No built-in plugin hooks into these events. Changes only add denials where silently passing was the bug.
- **[Risk] Scoping breaks legitimate cross-post-type drafts**: If any workflow creates drafts where parent post is in a different post_type than `@post_type`. → **Mitigation**: The route already ties drafts to a post type. Cross-post-type drafts are a bug, not a feature. Verified by code audit.
- **[Risk] Race condition between autosave and authorization**: If two users simultaneously save drafts for the same post, authorization passes for both but one overwrites the other. → **Accept**: This is existing behavior. Fixing it (with optimistic locking) is out of scope.
