## Why

The admin draft autosave endpoint (`DraftsController#create` and `#update`) performs no authorization checks and uses global-scoped queries, allowing any authenticated user to overwrite drafts belonging to other users. A low-privilege user can inject content into another user's draft, which can later be published by an authorized editor — a content integrity compromise.

## What Changes

- **`DraftsController#create`**: Scope the draft lookup to `@post_type.posts.drafts` (not global `Post.drafts`), add `authorize!` calls for create and update operations, and validate that `post_id` references a legitimate post.
- **`DraftsController#update`**: Scope the draft finder to `@post_type.posts.drafts` (not global `Post.drafts`), add `authorize!` call.
- **`DraftsController#set_post_data_params`**: Remove unconditional `post_parent` override from `params[:post_id]` — scoping to parent post that user can access.
- **Test coverage**: Add request specs for the drafts controller covering authorization scenarios.
- **Secondary**: `ThemesAdminController` — add a `before_action :authorize_theme` call matching the pattern used by `PluginsAdminController`. (Lower priority, deferred to separate change if out of scope.)

## Capabilities

### New Capabilities

- `draft-authorization`: The drafts controller scopes draft lookups to the current post type, requires `authorize!` before mutation, and validates that the referenced parent post exists and is accessible.

### Modified Capabilities

*(None — existing specs are unrelated to authorization boundaries.)*

## Impact

- **Controllers**: `app/controllers/camaleon_cms/admin/posts/drafts_controller.rb`
- **Tests**: New `spec/requests/security/draft_authorization_spec.rb`
- **Routes**: No route changes — only controller logic
- **No new dependencies**
