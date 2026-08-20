## Context

The `UsersController#profile` action (lines 17-22) is explicitly excluded from the `validate_role` before_action via `except: %i[profile profile_edit]`. Any authenticated user can view any other user's profile by passing `?user_id=X` to `GET /admin/profile`. The `profile_edit` action (which always operates on `cama_current_user`) is also excluded but does not accept a `user_id` parameter, so it only renders the current user's own profile — it is not vulnerable.

The existing `validate_role` guard enforces: `user_id = user_id_param; (user_id.present? && cama_current_user.id.to_s == user_id.to_s) || authorize!(:manage, :users)`. This is precisely the correct check.

## Goals / Non-Goals

**Goals:**
- Prevent non-admin users from reading arbitrary user profiles via the `profile` action
- Keep `profile_edit` working unchanged for self-service
- Follow existing patterns (`validate_role` guard style)

**Non-Goals:**
- No changes to the `show`, `edit`, or `update` actions (already protected by `set_user` + `validate_role`)
- No changes to `profile_edit` (not vulnerable)
- No redesign of the authorization model

## Decisions

1. **Add inline authorization check inside the `profile` action, keep `profile` excluded from `validate_role`**
   - Rationale: `validate_role` requires a `user_id` to compare — when `params[:user_id]` is absent (self-view without explicit ID), the guard receives `nil` and falls through to `authorize!(:manage, :users)`, which would **block** non-admin users from seeing their own profile. The `profile` action is the only action where the target user is optional (defaults to self). Adding `profile` to `validate_role` would break self-profile access for non-admin users.
   - Implementation: `authorize! :manage, :users if user_id.present? && @user.id != cama_current_user.id`
   - Alternative considered: Adding `profile` to `validate_role`'s `only` list. Rejected because it breaks self-view without `user_id`.

2. **Ensure `profile_edit` remains excluded** — it only loads `cama_current_user.object` with no user-controlled ID, so it's not vulnerable. No change needed.

## Risks / Trade-offs

- [Minor] Existing admin flows that render another user's profile via `GET /admin/profile?user_id=X` will continue to work because admins have `:manage :users` permission. No breakage expected.
- [None] The `the_admin_profile_url` decorator method (generates `/admin/profile?user_id=ID`) is only used in admin views accessible to users who already have appropriate permissions. No frontend impact.
