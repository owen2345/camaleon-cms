## 1. Authorization Fix

- [x] 1.1 Add inline `authorize!` check in `profile` action when targeting another user

## 2. Tests

- [x] 2.1 Add request spec for self-profile access (no `user_id` parameter)
- [x] 2.2 Add request spec for self-profile access (matching `user_id` parameter)
- [x] 2.3 Add request spec for admin viewing another user's profile
- [x] 2.4 Add request spec for non-admin attempting to view another user's profile (denied)

## 3. Verification

- [x] 3.1 Run the new specs: `bin/rspec spec/requests/admin/users_controller/profile_spec.rb`
- [x] 3.2 Run the related specs to check for regressions: `bin/rspec spec/requests/admin/users_controller/`
- [x] 3.3 Run linter: `bin/rubocop -A`
