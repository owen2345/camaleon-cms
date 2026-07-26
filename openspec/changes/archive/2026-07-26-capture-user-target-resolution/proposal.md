## Why

`CamaleonCms::Admin::UsersController` has now absorbed two parameter-confusion reports. The second one (PR [#1185](https://github.com/owen2345/camaleon-cms/pull/1185), commit `97e20509`) was a critical account takeover: `validate_role` authorized against one parameter while `updated_ajax` loaded the record to mutate from a different one, so an attacker could authorize themselves against their own account and overwrite an admin's password.

The rule that closed it — *authorization and mutation must resolve the target user through one canonical helper* — is recorded nowhere durable. It lives in a commit message and in one regression spec covering a single endpoint. `openspec/specs/` has a `profile-authorization` capability for `GET /admin/profile`, but nothing states the invariant that governs every other action in the controller.

Worse, half the surface the invariant protects has no test at all. No spec anywhere injects `?user_id=` on a member route (`/admin/users/:id`), and `spec/requests/admin/users_controller/update_spec.rb:15` stubs `validate_role` to return `true`, so the one request spec that exercises `update` contributes zero authorization coverage. The controller is correct on master today; nothing would catch it becoming incorrect.

## What Changes

- Add a new `user-target-resolution` capability spec stating the canonical-resolution invariant, its precedence rule, and the behavior required on both route families the controller exposes.
- Add regression specs for the member-route direction (`PATCH /admin/users/<victim>?user_id=<attacker>`), which is currently untested. These assert the parameter-confusion pivot fails and degrades to a harmless self-edit.
- Record the helper's precedence (`params[:user_id]` before `params[:id]`) and its one observable consequence: on member routes the injectable key wins over the path segment, so an admin's `PATCH /admin/users/A?user_id=B` edits **B**, not A. This is not a privilege escalation — authorization and mutation still agree, and an admin may edit either user — but it is surprising, so the spec states it rather than leaving it to be rediscovered.
- Rescue `ActiveRecord::RecordNotFound` in `updated_ajax` so an unresolvable target is reported in the action's own plain-text error format, reusing the existing `camaleon_cms.admin.users.message.error` translation, instead of falling through to the framework's default HTML error page.

The invariant itself needs no application code change — the controller already satisfies it on master. The only code touched is the `updated_ajax` rescue described above.

## Capabilities

### New Capabilities

- `user-target-resolution`: How `CamaleonCms::Admin::UsersController` resolves the target user for every action guarded by `validate_role`, and the requirement that the record authorized is always the record acted upon. Covers both route families — the nested route (`/admin/users/:user_id/updated_ajax`) and the member routes (`/admin/users/:id` for `show`/`edit`/`update`/`destroy`/`impersonate`).

### Modified Capabilities

None. `profile-authorization` covers `GET /admin/profile`, which is exempt from `validate_role` (`except: %i[profile profile_edit]`) and carries its own inline authorization. Its requirements are unchanged, and the boundary between the two capabilities is stated in the new spec.

## Impact

- **Specs (new):** `openspec/specs/user-target-resolution/spec.md` via this change's delta.
- **Tests (new):** member-route parameter-confusion coverage, precedence coverage, and unresolvable-target coverage under `spec/requests/admin/users_controller/`.
- **Application code:** one rescue clause added to `updated_ajax` in `app/controllers/camaleon_cms/admin/users_controller.rb`, plus its three failure renders converted from `render inline:` to `render plain:`. No new translation keys.
- **Behavior:** an unresolvable target on `PATCH /admin/users/:user_id/updated_ajax` keeps its `404` status but gains a text body in place of the framework's HTML error page. The `400` and `422` failure bodies are unchanged in content but now carry `text/plain` instead of `text/html`. Everything else in this change is documentation plus regression coverage of already-shipped behavior.
- **Out of band:** the branch also carries a correction to the skip-ci guidance in `docs/ai/workflows.md`. It is unrelated to this capability, is recorded in `CHANGELOG.md`, and is deliberately not represented in these artifacts.
- **Not a security fix.** Only a caller holding `:manage` on `:users` can reach the lookup with an id that is not their own — `validate_role` rejects everyone else first — so this path is not an existence oracle and needs none of the response-shape uniformity that PR [#1213](https://github.com/owen2345/camaleon-cms/pull/1213) required for `GET /admin/profile`.
- **Code referenced but not modified:** `validate_role`, `user_id_param`, `set_user`, `config/routes/admin.rb`.
- **Known coverage caveat:** `update_spec.rb:15` stubs `validate_role`. That spec targets avatar-meta persistence, not authorization, so this change adds dedicated authorization specs alongside it rather than unpicking an unrelated stub.
