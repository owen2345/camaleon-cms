## Purpose

Define how `CamaleonCms::Admin::UsersController` resolves the target user for every action guarded by `validate_role`, and require that the record authorized is always the record acted upon. Covers both route families the controller exposes: the nested route (`PATCH /admin/users/:user_id/updated_ajax`) and the member routes (`/admin/users/:id` for `show`/`edit`/`update`/`destroy`/`impersonate`).

`GET /admin/profile` is exempt from `validate_role` and is governed by the `profile-authorization` capability instead.
## Requirements

### Requirement: Target user resolution is canonical across authorization and mutation

Every action in `CamaleonCms::Admin::UsersController` guarded by the `validate_role` filter SHALL resolve its target user through a single canonical parameter helper, and SHALL authorize and act upon the same resolved user.

No action SHALL read its target user from a request parameter that the authorization filter did not consult. Where an action loads a record directly rather than through the shared `set_user` filter, it SHALL use the same helper.

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

Coverage note: `spec/requests/admin/users_controller/updated_ajax_vulnerability_spec.rb` satisfies the two nested-route scenarios above. That file is older than this capability. It came with the fix that closed the original takeover. It is named here so the dependency is visible: deleting that file would strip half of this requirement's coverage without touching anything this capability introduced. The two member-route scenarios are satisfied by `spec/requests/admin/users_controller/member_route_target_resolution_spec.rb`.

### Requirement: The profile actions are outside the validate_role resolution

`profile` and `profile_edit` are exempt from the `validate_role` filter (`except: %i[profile profile_edit]`) and SHALL carry their own inline authorization. The `profile-authorization` capability SHALL govern their behavior, not this capability.

#### Scenario: A profile action is not governed by this capability

- **WHEN** a request reaches `profile` or `profile_edit`
- **THEN** the `validate_role` filter does not run for it
- **AND** the `profile-authorization` capability governs its behavior

### Requirement: The canonical helper resolves one ordered parameter chain

The canonical helper SHALL resolve the target user id from `params[:user_id]` first, and SHALL fall back to `params[:id]`.

This ordering is deliberate for the nested route `PATCH /admin/users/:user_id/updated_ajax`, where the path segment lands in `params[:user_id]`.

#### Scenario: Nested route with no injected key resolves to the path segment

- **WHEN** an admin sends `PATCH /admin/users/<TARGET_ID>/updated_ajax` with new `password` parameters and no `id` parameter
- **THEN** the system updates the password of the user identified by the path segment

#### Scenario: Member route with no injected key resolves to the path segment

- **WHEN** an admin sends `PATCH /admin/users/<TARGET_ID>` with `user` attributes and no `user_id` parameter
- **THEN** the system updates the user identified by the path segment

#### Scenario: A path segment wins over a query value on the nested route

- **WHEN** a request is sent to `PATCH /admin/users/<USER_A_ID>/updated_ajax?user_id=<USER_B_ID>`
- **THEN** `params[:user_id]` is user A
- **AND** a path segment always overrides a query-string or body value of the same name, because Rails merges path parameters last (`ActionDispatch::Http::Parameters#parameters`)
- **AND** `params[:id]` is absent from the route, so it can only arrive by injection

### Requirement: Only a scalar user_id takes part in resolution

Only a **scalar** `user_id` SHALL participate in resolution. When `params[:user_id]` is non-scalar (an array or hash, for example `?user_id[]=X`), the helper SHALL ignore it and resolve from `params[:id]`. So a malformed injection can neither crash the action nor change which record the authorization filter and the lookup agree on.

#### Scenario: Non-scalar user_id falls back to the path segment

- **WHEN** an admin sends `PATCH /admin/users/<USER_A_ID>?user_id[]=<USER_B_ID>` with `user` attributes
- **THEN** the system updates user A (the path segment)
- **AND** user B is unchanged
- **AND** the response is not a server error

#### Scenario: Non-scalar user_id does not deny a self-edit

- **WHEN** a non-admin sends `PATCH /admin/users/<OWN_ID>?user_id[]=<OTHER_ID>` with `user` attributes
- **THEN** the system updates only the caller's own record
- **AND** the other user is unchanged

### Requirement: On the member routes an injected user_id takes precedence over the path segment

On the member routes `/admin/users/:id`, the path segment lands in `params[:id]`, so an injected `user_id` SHALL take precedence over it. The authorization filter and the record lookup SHALL still resolve the same user.

#### Scenario: Member route with an injected user_id resolves to the injected value

- **WHEN** an admin sends `PATCH /admin/users/<USER_A_ID>?user_id=<USER_B_ID>` with `user` attributes
- **THEN** the system updates user B
- **AND** user A is unchanged

This is not a privilege escalation, because any caller who passes the filter for that user is entitled to act on them. It is observable, so this requirement specifies it rather than leaves it implicit.

#### Scenario: Impersonate resolves the injected value in preference to the path segment

- **WHEN** an admin sends `GET /admin/users/<USER_A_ID>/impersonate?user_id=<USER_B_ID>`
- **THEN** the session switches to user B
- **AND** the session does not switch to user A

Note: this scenario is the one that exercises `impersonate` against target resolution. It uses an admin caller deliberately — an admin holds `can :manage, :all`, so the resolved target alone decides the outcome. A non-admin caller cannot test this, because `cannot :impersonate` denies them whichever user resolves.

### Requirement: Unresolvable targets are reported in the endpoint's own error format

The canonical helper can resolve to an id that does not identify a user visible to the current site. Then `PATCH /admin/users/:user_id/updated_ajax` SHALL respond with `404 Not Found`. The plain-text body SHALL carry the existing `camaleon_cms.admin.users.message.error` translation. It SHALL NOT fall through to the framework's default HTML error page.

#### Scenario: Authorized caller requests a nonexistent user

- **WHEN** a user authorized to manage users sends `PATCH /admin/users/<NONEXISTENT_ID>/updated_ajax` with valid `password` parameters
- **THEN** the system responds with `404 Not Found`
- **AND** the response body is the "not found user" message rather than an HTML error page
- **AND** no user record is modified

#### Scenario: Authorized caller supplies a non-numeric user id

- **WHEN** a user authorized to manage users sends `PATCH /admin/users/abc/updated_ajax` with valid `password` parameters
- **THEN** the system responds with `404 Not Found`
- **AND** the response body is the "not found user" message rather than an HTML error page

#### Scenario: Authorized caller requests a deleted user

- **WHEN** a user authorized to manage users sends `PATCH /admin/users/<DELETED_ID>/updated_ajax` with valid `password` parameters
- **THEN** the system responds with `404 Not Found`
- **AND** the response body is the "not found user" message rather than an HTML error page

#### Scenario: The not-found response adds no translation key

- **WHEN** the endpoint reports an unresolvable target
- **THEN** the body uses the existing translation, and no new translation key is introduced
- **AND** the `404` status is unchanged, because `ActiveRecord::RecordNotFound` already maps to `:not_found`, and only the body format changes

### Requirement: The endpoint reports its other failures as a status plus a short text body

`PATCH /admin/users/:user_id/updated_ajax` SHALL report its other failures as a status plus a short text body. It SHALL answer `400` for a missing `password` parameter and `422` for a validation error.

#### Scenario: Parameter errors keep their existing message

- **WHEN** a user authorized to manage users sends `PATCH /admin/users/<VALID_ID>/updated_ajax` omitting `password_confirmation`
- **THEN** the system responds with `400 Bad Request` and the existing `ActionController::ParameterMissing` message, unchanged by this capability

#### Scenario: A validation error answers with 422

- **WHEN** a user authorized to manage users sends `PATCH /admin/users/<VALID_ID>/updated_ajax` with a password that fails validation
- **THEN** the system responds with `422` and a short text body

### Requirement: Every failure path of the endpoint answers as text/plain

All three failure paths of `PATCH /admin/users/:user_id/updated_ajax` SHALL answer as `text/plain`, and no failure body SHALL be compiled as an ERB template.

#### Scenario: Every failure path answers as text/plain

- **WHEN** `PATCH /admin/users/:user_id/updated_ajax` fails because the target cannot be resolved, because a `password` parameter is missing, or because the password fails validation
- **THEN** each response carries a `text/plain` media type
- **AND** no failure body is compiled as an ERB template

The failure paths previously used `render inline:`, which compiles its argument as an ERB template. A template is needless for a fixed message. On the `422` path it is a template-injection sink, because validation messages make the body and can carry user-influenced content.

Note on the shipped admin UI: the modal password form posts through `$.post`. It renders the response body only from its success callback, which does not fire for a non-2xx response. The admin JavaScript registers no global `ajaxError` handler. So none of these failure bodies currently reach a user through that form. The requirement is about the endpoint presenting one coherent contract to any client, not about what the bundled modal displays today.

Note: unlike `GET /admin/profile`, this endpoint requires no uniformity between "found" and "not found" responses. `validate_role` rejects any caller who is neither the target nor a holder of `:manage` on `:users`. So only a caller that can already enumerate users can reach the lookup with the id of another user. This requirement is about response format, not about disclosure.

### Requirement: Callers without user-management permission can only target themselves

A caller who lacks `:manage` permission on `:users` SHALL NOT read, modify, delete, or impersonate any user other than themselves through this controller, under any arrangement of the `user_id` and `id` request parameters.

Any request from such a caller that resolves to a user other than themselves SHALL be denied before the target record is acted upon.

#### Scenario: Non-admin is denied when the resolved target is not themselves

- **WHEN** a non-admin user sends a request to any `validate_role`-guarded action that resolves to a user other than themselves
- **THEN** the system denies the request and does not act upon the target record

This scenario states the security outcome independently of the mechanism that currently delivers it, so that it survives refactoring of the helper.

#### Scenario: Non-admin cannot impersonate another user

- **WHEN** a non-admin user sends `GET /admin/users/<ADMIN_ID>/impersonate`, with or without an injected `user_id` parameter
- **THEN** the system denies the request
- **AND** the caller's session is not switched to the admin

Note on what enforces this scenario: denial here comes from `cannot :impersonate` in `CamaleonCms::Ability`, which rejects a non-admin caller whichever user the request resolves to. The scenario therefore holds even if target resolution were to regress — it is defense in depth for the outcome, not a test of the resolution mechanism. The resolution behavior of `impersonate` is exercised by the admin-caller scenario under the precedence requirement above. Both are kept deliberately: this one pins the outcome a reader of this requirement cares about, that one pins the mechanism.

### Requirement: The self-exemption applies only to actions with a single target user

The `validate_role` self-exemption lets a caller act without `:manage` on `:users` when the resolved target is their own record. It SHALL apply only to actions that resolve a single target user (`show`, `edit`, `update`, `destroy`, `impersonate`, `updated_ajax`).

#### Scenario: The member self-exemption is unchanged

- **WHEN** a caller lacking `:manage` on `:users` sends `PATCH /admin/users/<OWN_ID>/updated_ajax` with new `password` parameters
- **THEN** the system updates the caller's own password

### Requirement: Collection actions are not subject to the self-target exemption

The collection actions `index`, `new`, and `create` resolve no such target. They SHALL require `:manage` on `:users` regardless of any `user_id` parameter, so a self-referential `?user_id=<own id>` cannot exempt them.

#### Scenario: Self-referential user_id does not expose the user index

- **WHEN** a caller lacking `:manage` on `:users` sends `GET /admin/users?user_id=<OWN_ID>`
- **THEN** the system denies the request and redirects to the admin dashboard
- **AND** the user table is not rendered
- **AND** the exemption's `user_id == current_user` check does not short-circuit the capability check, because the action has no target user

#### Scenario: Self-referential user_id does not permit account creation

- **WHEN** a caller lacking `:manage` on `:users` sends `POST /admin/users?user_id=<OWN_ID>` with `user` attributes
- **THEN** the system denies the request and redirects to the admin dashboard
- **AND** no user record is created
- **AND** the `permit_create_account` registration gate is not bypassed

#### Scenario: Self-referential user_id does not expose the new-user form

- **WHEN** a caller lacking `:manage` on `:users` sends `GET /admin/users/new?user_id=<OWN_ID>`
- **THEN** the system denies the request and redirects to the admin dashboard

#### Scenario: A user-management holder still reaches the collection actions

- **WHEN** a caller holding `:manage` on `:users` sends `GET /admin/users`, and separately `POST /admin/users` with valid `user` attributes
- **THEN** the index renders, and the account is created, respectively
