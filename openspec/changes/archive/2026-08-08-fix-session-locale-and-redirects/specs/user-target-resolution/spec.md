## MODIFIED Requirements

### Requirement: The canonical helper resolves one ordered parameter chain

The canonical helper SHALL resolve the target user id from `params[:user_id]` first, falling back to `params[:id]`. Only a **scalar** `user_id` SHALL participate in resolution: when `params[:user_id]` is non-scalar (an array or hash, e.g. `?user_id[]=X`), the helper SHALL ignore it and resolve from `params[:id]`, so a malformed injection can neither crash the action nor change which record the authorization filter and the lookup agree on.

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

#### Scenario: Non-scalar user_id falls back to the path segment

- **WHEN** an admin sends `PATCH /admin/users/<USER_A_ID>?user_id[]=<USER_B_ID>` with `user` attributes
- **THEN** the system updates user A (the path segment)
- **AND** user B is unchanged
- **AND** the response is not a server error

#### Scenario: Non-scalar user_id does not deny a self-edit

- **WHEN** a non-admin sends `PATCH /admin/users/<OWN_ID>?user_id[]=<OTHER_ID>` with `user` attributes
- **THEN** the system updates only the caller's own record
- **AND** the other user is unchanged
