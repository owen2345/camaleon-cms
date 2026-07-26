## Purpose

Define how `CamaleonCms::Admin::UsersController` resolves the target user for every action guarded by `validate_role`, and require that the record authorized is always the record acted upon. Covers both route families the controller exposes: the nested route (`PATCH /admin/users/:user_id/updated_ajax`) and the member routes (`/admin/users/:id` for `show`/`edit`/`update`/`destroy`/`impersonate`).

`GET /admin/profile` is exempt from `validate_role` and is governed by the `profile-authorization` capability instead.

## Requirements

### Requirement: Target user resolution is canonical across authorization and mutation

Every action in `CamaleonCms::Admin::UsersController` guarded by the `validate_role` filter SHALL resolve its target user through a single canonical parameter helper, and SHALL authorize and act upon the same resolved user.

No action SHALL read its target user from a request parameter that the authorization filter did not consult. Where an action loads a record directly rather than through the shared `set_user` filter, it SHALL use the same helper.

Scope: this requirement governs the actions covered by `validate_role`. `profile` and `profile_edit` are exempt from that filter (`except: %i[profile profile_edit]`) and carry their own inline authorization; their behavior is governed by the `profile-authorization` capability, not this one.

Coverage note: the two nested-route scenarios below are satisfied by `spec/requests/admin/users_controller/updated_ajax_vulnerability_spec.rb`, which predates this capability — it was added with the fix that closed the original takeover. It is named here so the dependency is visible: deleting that file would strip half of this requirement's coverage without touching anything this capability introduced. The two member-route scenarios are satisfied by `spec/requests/admin/users_controller/member_route_target_resolution_spec.rb`.

#### Scenario: Nested-route pivot cannot mutate another user

- **WHEN** a non-admin user sends `PATCH /admin/users/<ADMIN_ID>/updated_ajax?id=<OWN_ID>` with new `password` parameters
- **THEN** the system denies the request and redirects to the admin dashboard
- **AND** the admin's password is unchanged

#### Scenario: Nested-route reverse pivot degrades to a self-edit

- **WHEN** a non-admin user sends `PATCH /admin/users/<OWN_ID>/updated_ajax?id=<ADMIN_ID>` with new `password` parameters
- **THEN** the system updates only the caller's own password
- **AND** the admin's password is unchanged

#### Scenario: Member-route pivot cannot mutate another user

- **WHEN** a non-admin user sends `PATCH /admin/users/<VICTIM_ID>?user_id=<OWN_ID>` with `user` attributes
- **THEN** the victim's record is unchanged
- **AND** the caller's own record is the only record written

#### Scenario: Member-route pivot cannot delete another user

- **WHEN** a non-admin user sends `DELETE /admin/users/<VICTIM_ID>?user_id=<OWN_ID>`
- **THEN** the victim's record still exists
- **AND** the caller's own record still exists, because the controller refuses self-deletion

### Requirement: The canonical helper resolves one ordered parameter chain

The canonical helper SHALL resolve the target user id from `params[:user_id]` first, falling back to `params[:id]`.

This ordering is deliberate for the nested route `PATCH /admin/users/:user_id/updated_ajax`, where the path segment lands in `params[:user_id]` and is therefore not attacker-controllable, while `params[:id]` is absent from the route and can only arrive by injection. Rails merges path parameters last (`ActionDispatch::Http::Parameters#parameters`), so a path segment always overrides a query-string or body value of the same name.

On the member routes `/admin/users/:id` the ordering inverts which key is authoritative: the path segment lands in `params[:id]`, so an injected `user_id` takes precedence over it. This is not a privilege escalation — the authorization filter and the record lookup still resolve the same user, and any caller who passes the filter for that user is entitled to act on them — but it is observable, so it is specified here rather than left implicit.

#### Scenario: Nested route with no injected key resolves to the path segment

- **WHEN** an admin sends `PATCH /admin/users/<TARGET_ID>/updated_ajax` with new `password` parameters and no `id` parameter
- **THEN** the system updates the password of the user identified by the path segment

#### Scenario: Member route with no injected key resolves to the path segment

- **WHEN** an admin sends `PATCH /admin/users/<TARGET_ID>` with `user` attributes and no `user_id` parameter
- **THEN** the system updates the user identified by the path segment

#### Scenario: Member route with an injected user_id resolves to the injected value

- **WHEN** an admin sends `PATCH /admin/users/<USER_A_ID>?user_id=<USER_B_ID>` with `user` attributes
- **THEN** the system updates user B
- **AND** user A is unchanged

#### Scenario: Impersonate resolves the injected value in preference to the path segment

- **WHEN** an admin sends `GET /admin/users/<USER_A_ID>/impersonate?user_id=<USER_B_ID>`
- **THEN** the session switches to user B
- **AND** the session does not switch to user A

Note: this scenario is the one that exercises `impersonate` against target resolution. It uses an admin caller deliberately — an admin holds `can :manage, :all`, so the resolved target alone decides the outcome. A non-admin caller cannot test this, because `cannot :impersonate` denies them whichever user resolves.

### Requirement: Unresolvable targets are reported in the endpoint's own error format

When the canonical helper resolves to an id that does not identify a user visible to the current site, `PATCH /admin/users/:user_id/updated_ajax` SHALL respond with `404 Not Found` and a plain-text body carrying the existing `camaleon_cms.admin.users.message.error` translation. It SHALL NOT fall through to the framework's default HTML error page.

This matches how the action already reports its other failures — a status plus a short text body: `400` for a missing `password` parameter, `422` for a validation error. The `404` status itself is unchanged: `ActiveRecord::RecordNotFound` already maps to `:not_found`. Only the body format changes.

All three failure paths SHALL answer as `text/plain`. They previously used `render inline:`, which compiles its argument as an ERB template. That is needless for a fixed message and is a template-injection sink on the `422` path, whose body is assembled from validation messages and can therefore carry user-influenced content.

This applies to nonexistent ids, ids of deleted users, and non-numeric values. No new translation keys are introduced.

Note on the shipped admin UI: the modal password form posts through `$.post` and renders the response body only from its success callback, which does not fire for a non-2xx response, and the admin JavaScript registers no global `ajaxError` handler. So none of these failure bodies currently reach a user through that form. The requirement is about the endpoint presenting one coherent contract to any client, not about what the bundled modal displays today.

Note: unlike `GET /admin/profile`, this endpoint requires no uniformity between "found" and "not found" responses. `validate_role` rejects any caller who is neither the target nor a holder of `:manage` on `:users`, so only a caller already entitled to enumerate users can reach the lookup with someone else's id. This requirement is about response format, not about disclosure.

#### Scenario: Authorized caller requests a nonexistent user

- **WHEN** a user authorized to manage users sends `PATCH /admin/users/<NONEXISTENT_ID>/updated_ajax` with valid `password` parameters
- **THEN** the system responds with `404 Not Found`
- **AND** the response body is the "not found user" message rather than an HTML error page
- **AND** no user record is modified

#### Scenario: Authorized caller supplies a non-numeric user id

- **WHEN** a user authorized to manage users sends `PATCH /admin/users/abc/updated_ajax` with valid `password` parameters
- **THEN** the system responds with `404 Not Found`
- **AND** the response body is the "not found user" message rather than an HTML error page

#### Scenario: Parameter errors keep their existing message

- **WHEN** a user authorized to manage users sends `PATCH /admin/users/<VALID_ID>/updated_ajax` omitting `password_confirmation`
- **THEN** the system responds with `400 Bad Request` and the existing `ActionController::ParameterMissing` message, unchanged by this capability

#### Scenario: Every failure path answers as text/plain

- **WHEN** `PATCH /admin/users/:user_id/updated_ajax` fails because the target cannot be resolved, because a `password` parameter is missing, or because the password fails validation
- **THEN** each response carries a `text/plain` media type
- **AND** no failure body is compiled as an ERB template

### Requirement: Callers without user-management permission can only target themselves

A caller who lacks `:manage` permission on `:users` SHALL NOT read, modify, delete, or impersonate any user other than themselves through this controller, under any arrangement of the `user_id` and `id` request parameters.

Any request from such a caller that resolves to a user other than themselves SHALL be denied before the target record is acted upon.

This requirement states the security outcome independently of the mechanism that currently delivers it, so that it survives refactoring of the helper.

#### Scenario: Non-admin is denied when the resolved target is not themselves

- **WHEN** a non-admin user sends a request to any `validate_role`-guarded action that resolves to a user other than themselves
- **THEN** the system denies the request and does not act upon the target record

#### Scenario: Non-admin cannot impersonate another user

- **WHEN** a non-admin user sends `GET /admin/users/<ADMIN_ID>/impersonate`, with or without an injected `user_id` parameter
- **THEN** the system denies the request
- **AND** the caller's session is not switched to the admin

Note on what enforces this scenario: denial here comes from `cannot :impersonate` in `CamaleonCms::Ability`, which rejects a non-admin caller whichever user the request resolves to. The scenario therefore holds even if target resolution were to regress — it is defense in depth for the outcome, not a test of the resolution mechanism. The resolution behavior of `impersonate` is exercised by the admin-caller scenario under the precedence requirement above. Both are kept deliberately: this one pins the outcome a reader of this requirement cares about, that one pins the mechanism.
