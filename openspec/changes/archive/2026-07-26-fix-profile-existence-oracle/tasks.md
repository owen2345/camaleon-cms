## 1. Branch

- [x] 1.1 Create branch `security/fix-profile-existence-oracle` off `master`

## 2. Reproduce first

- [x] 2.1 Add a failing request spec asserting that a `client`-role user gets the same status and redirect target for an existing-but-forbidden `user_id`, a nonexistent `user_id`, and a non-numeric `user_id` (currently `500` vs `302`)
- [x] 2.2 Add a failing request spec asserting an admin gets a redirect + flash, not a `500`, for a nonexistent `user_id`
- [x] 2.3 Confirm both fail on the unmodified controller

## 3. Fix

- [x] 3.1 In `Admin::UsersController#profile`, move `authorize! :manage, :users` above the `@user` assignment and derive it from `params[:user_id].to_i` rather than `@user.id`
- [x] 3.2 Make the lookup nil-safe (`the_user(...)&.object`) and, when it yields nil, set `flash[:error] = t('camaleon_cms.admin.users.message.error')` and redirect to `cama_admin_path`, matching the `set_user` idiom
- [x] 3.3 Confirm the specs from section 2 now pass

## 4. Tests

- [x] 4.1 ~~Extend with the cross-site `user_id` case~~ — dropped. `Site#users` (`site.rb:157`) returns `CamaleonCms::User.all` when `users_share_sites` is enabled, which is the shipped default, so a user of another site is an ordinary resolvable user rather than a not-found case. Artifacts corrected accordingly.
- [x] 4.2 Verify the four pre-existing scenarios in that spec still pass unchanged (self without `user_id`, self with matching `user_id`, admin viewing another user, non-admin denied)
- [x] 4.3 Add an array-shaped `user_id` case (`?user_id[]=1`), found during implementation to hit the same `500`. Covered by the same nil guard with no extra coercion, because `Array#to_i` (`lib/ext/array.rb:24`) yields an Array that `the_user` rejects.

## 5. Verification

- [x] 5.1 `bin/rspec spec/requests/admin/users_controller/` — 15 examples, 0 failures
- [x] 5.2 `bin/rspec` (full suite, regression check) — 758 examples, 0 failures
- [x] 5.3 `bin/rubocop -A` on touched files only — no offenses
- [x] 5.4 `bin/brakeman --no-pager` — 0 security warnings
- [x] 5.5 `(cd spec/dummy && bin/rails zeitwerk:check)` — all is good

## 6. Documentation

- [x] 6.1 Add a CHANGELOG.md entry under the unreleased section, noting it as a follow-up hardening to [#1197](https://github.com/owen2345/camaleon-cms/pull/1197)
