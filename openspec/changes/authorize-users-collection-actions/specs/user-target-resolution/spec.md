## ADDED Requirements

### Requirement: Collection actions are not subject to the self-target exemption

The `validate_role` self-exemption — which lets a caller act without `:manage` on `:users` when the resolved target is their own record — SHALL apply only to actions that resolve a single target user (`show`, `edit`, `update`, `destroy`, `impersonate`, `updated_ajax`). The collection actions `index`, `new`, and `create` resolve no such target and SHALL require `:manage` on `:users` regardless of any `user_id` parameter, so a self-referential `?user_id=<own id>` cannot exempt them.

This closes a gap where a caller lacking `:manage` on `:users` could list every user (`GET /admin/users?user_id=<own id>`) or create an account (`POST /admin/users?user_id=<own id>`, also bypassing the `permit_create_account` registration gate) by injecting their own id, because the exemption's `user_id == current_user` check short-circuited the capability check on an action that has no target user.

#### Scenario: Self-referential user_id does not expose the user index

- **WHEN** a caller lacking `:manage` on `:users` sends `GET /admin/users?user_id=<OWN_ID>`
- **THEN** the system denies the request and redirects to the admin dashboard
- **AND** the user table is not rendered

#### Scenario: Self-referential user_id does not permit account creation

- **WHEN** a caller lacking `:manage` on `:users` sends `POST /admin/users?user_id=<OWN_ID>` with `user` attributes
- **THEN** the system denies the request and redirects to the admin dashboard
- **AND** no user record is created

#### Scenario: Self-referential user_id does not expose the new-user form

- **WHEN** a caller lacking `:manage` on `:users` sends `GET /admin/users/new?user_id=<OWN_ID>`
- **THEN** the system denies the request and redirects to the admin dashboard

#### Scenario: A user-management holder still reaches the collection actions

- **WHEN** a caller holding `:manage` on `:users` sends `GET /admin/users`, and separately `POST /admin/users` with valid `user` attributes
- **THEN** the index renders, and the account is created, respectively

#### Scenario: The member self-exemption is unchanged

- **WHEN** a caller lacking `:manage` on `:users` sends `PATCH /admin/users/<OWN_ID>/updated_ajax` with new `password` parameters
- **THEN** the system updates the caller's own password
