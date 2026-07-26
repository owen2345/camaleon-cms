## 1. Branch

- [x] 1.1 Create branch `security/capture-user-target-resolution` from `master` per AGENTS.md Phase 1

## 2. Member-route parameter-confusion coverage

- [x] 2.1 Add `spec/requests/admin/users_controller/member_route_target_resolution_spec.rb`, modelled on `updated_ajax_vulnerability_spec.rb` (real login via `cama_admin_login_path`, no `validate_role` stub)
- [x] 2.2 Cover: non-admin sends `PATCH /admin/users/<victim>?user_id=<own_id>` with `user` attributes → victim's record unchanged, only the caller's own record written
- [x] 2.3 Cover: non-admin sends `DELETE /admin/users/<victim>?user_id=<own_id>` → victim still exists, caller still exists (self-deletion refused)
- [x] 2.4 Cover: non-admin sends `GET /admin/users/<admin_id>/impersonate`, with and without an injected `user_id` → denied, session not switched
- [x] 2.5 Cover: non-admin sends `PATCH /admin/users/<victim>` with no injected key → denied, victim unchanged

## 3. Precedence coverage

- [x] 3.1 Cover: admin sends `PATCH /admin/users/<target>` with no `user_id` parameter → the path-segment user is updated
- [x] 3.2 Cover: admin sends `PATCH /admin/users/<user_a>?user_id=<user_b>` → user B is updated, user A unchanged (pins the documented member-route precedence consequence)
- [x] 3.3 Cover: admin sends `PATCH /admin/users/<target>/updated_ajax` with no `id` parameter → the path-segment user's password is updated
- [x] 3.4 Confirm the two existing nested-route scenarios in `updated_ajax_vulnerability_spec.rb` already satisfy the corresponding spec scenarios; if so, leave that file untouched and note the mapping in the PR description

## 4. Unresolvable-target handling

- [x] 4.1 Add a failing spec first: admin sends `PATCH /admin/users/<nonexistent_id>/updated_ajax` with valid `password` params → expect `404` and the "not found user" body; confirm it fails against current master with an HTML error page
- [x] 4.2 Add `rescue ActiveRecord::RecordNotFound` to `updated_ajax`, rendering `t('camaleon_cms.admin.users.message.error')` with `status: :not_found`; catch that class only, never `StandardError`
- [x] 4.3 Place the new rescue so it does not shadow the existing `ActionController::ParameterMissing` rescue, and confirm the existing 400 behaviour in `updated_ajax_spec.rb:45` still passes unchanged
- [x] 4.4 Cover: admin sends `PATCH /admin/users/abc/updated_ajax` (non-numeric id) → same `404` and body
- [x] 4.5 Cover: no user record is modified on either unresolvable-target path
- [x] 4.6 Confirm no new translation key was added — `camaleon_cms.admin.users.message.error` already exists and is used by `set_user`

## 5. Verification

- [x] 5.1 `bin/rspec spec/requests/admin/users_controller/` — all green
- [x] 5.2 Confirm each new resolution spec fails when `user_id_param` is temporarily reverted to `params[:id] || params[:user_id]` *and* `updated_ajax` is reverted to read `params[:user_id]` directly, proving the specs pin the invariant rather than passing incidentally; revert the experiment
- [x] 5.3 `bin/rubocop -A` on touched files only
- [x] 5.4 `bin/brakeman --no-pager`
- [x] 5.5 `(cd spec/dummy && bin/rails zeitwerk:check)`
- [ ] 5.6 `bin/rspec` full suite

## 6. Documentation

- [ ] 6.1 Add a CHANGELOG.md entry under Unreleased covering both parts: the captured invariant with its new coverage, and the `updated_ajax` error-format fix
- [ ] 6.2 Classify as **Developer tooling** / **Fix**, not **Security fix** — no vulnerability is being fixed, and the rescue closes a response-format inconsistency, not an oracle
- [ ] 6.3 Cross-reference PR [#1185](https://github.com/owen2345/camaleon-cms/pull/1185) as the fix this change retroactively specifies

## 7. Close out

- [x] 7.1 Self-audit against `docs/ai/criteria.md`
- [ ] 7.2 Open the PR; state that the only application code change is the `updated_ajax` rescue, and that the rest of the diff is specs plus tests
- [ ] 7.3 Run `/opsx:verify`, then `/opsx:archive` once merged, syncing `user-target-resolution` into `openspec/specs/`
