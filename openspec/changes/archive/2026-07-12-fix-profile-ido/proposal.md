## Why

The `UsersController#profile` action is excluded from the `validate_role` authorization guard, allowing any authenticated low-privilege user (e.g., "client" role) to read any other user's profile data — including email, username, role, and custom fields — by passing an arbitrary `user_id` query parameter. This enables silent user enumeration and information disclosure.

## What Changes

- Add authorization enforcement to the `profile` action so that non-admin users can only view their own profile
- Add request specs covering the profile action with various authorization scenarios

## Capabilities

### New Capabilities
- `profile-authorization`: Enforce that the admin profile endpoint (`GET /admin/profile`) only returns the requested user's data when the current user is authorized (self or has `:manage :users` permission)

### Modified Capabilities

None.

## Impact

- `app/controllers/camaleon_cms/admin/users_controller.rb` — add authorization check to `profile` action or remove it from `validate_role`'s `except` list
- `spec/requests/admin/users_controller/` — add request specs for the profile action
