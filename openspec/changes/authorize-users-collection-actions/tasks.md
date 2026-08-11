## 1. Branch

- [x] 1.1 Create branch `security/authorize-users-collection-actions` off the latest `master` and announce it
- [x] 1.2 Confirm the triage verdict before writing the fix — ✅ legit; reproduced the index/create bypass as a `client`; enumeration in `proposal.md`

## 2. Reproduce first

- [x] 2.1 Add `spec/requests/admin/users_controller/collection_authorization_spec.rb`: sign in as a low-privilege `client`, and assert `GET /admin/users?user_id=<own>`, `GET /admin/users/new?user_id=<own>`, and `POST /admin/users?user_id=<own>` are each denied (redirect to the dashboard) and create no user
- [x] 2.2 Add the no-injection control (bare `GET /admin/users` already denied) and the manager cases (index renders, create succeeds) so the injected `user_id` is shown to be the bypass
- [x] 2.3 Add a member self-service regression guard: a `client` changing their own password via `updated_ajax` still succeeds
- [x] 2.4 Confirm the three injection examples fail against the unfixed branch before writing the fix

## 3. Fix

- [x] 3.1 Introduce `SELF_TARGET_ACTIONS = %w[show edit update destroy impersonate updated_ajax]` and rewrite `validate_role` to apply the self-exemption only when `action_name` is in that set; every other action requires `:manage, :users`
- [x] 3.2 Leave the member-action exemption logic (`user_id_param`, the id comparison) unchanged — `design.md` D2
- [x] 3.3 Confirm the spec from section 2 now passes

## 4. Cover the unchanged paths

- [x] 4.1 Run the full `spec/requests/admin/users_controller/` suite and confirm the member/target-resolution/updated_ajax specs stay green
- [x] 4.2 Run the full request suite (`spec/requests/`) and confirm no authorization regression elsewhere

## 5. Verification

- [x] 5.1 `bin/rspec` on the touched specs and `spec/requests/` — green
- [x] 5.2 `bin/rubocop` on touched files only — no offenses
- [x] 5.3 `bin/brakeman --no-pager` — no new warnings
- [x] 5.4 `(cd spec/dummy && bin/rails zeitwerk:check)`

## 6. Changelog and archive

- [x] 6.1 Add a `## Unreleased` **Security fix** entry: the collection-action gap, the privilege (any authenticated user), and what it exposed (the user table + account creation bypassing `permit_create_account`)
- [ ] 6.2 Archive the change on the branch before merge, committed as part of the PR (`docs/ai/workflows.md` Phase 4)
