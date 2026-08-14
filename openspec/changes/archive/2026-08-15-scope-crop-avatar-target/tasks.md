# Tasks

## 1. Reproduce first

- [x] 1.1 `spec/requests/security/crop_avatar_target_scope_spec.rb`: with users not shared, cropping
  must not set a foreign user's avatar; a same-site user's avatar still updates
- [x] 1.2 Confirm the cross-site write succeeds against the unscoped `User.find` (stash-verified)

## 2. Fix

- [x] 2.1 Resolve the avatar target through `current_site.users.find_by(id:)` and write only when found

## 3. Verification

- [x] 3.1 `bin/rubocop` — no offenses
- [x] 3.2 `bin/rspec` the new spec + `spec/requests/admin/media_controller/crop_spec.rb` — green
- [x] 3.3 Full-suite + brakeman + zeitwerk at bundle presentation time
- [x] 3.4 Changelog + archive at ship time
