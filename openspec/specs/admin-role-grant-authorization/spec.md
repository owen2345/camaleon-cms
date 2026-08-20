# admin-role-grant-authorization Specification

## Purpose
Pin that the `admin` role — the role `User#admin?` tests, which `Ability` maps to `can :manage, :all` —
can be granted or removed only by an existing admin. Holding `:manage, :users` lets a user manage accounts
and change non-admin roles, but must not be a path to minting an admin (escalating to superadmin) or to
stripping an existing admin. The same protection extends to an admin's login credentials: a
`:manage, :users` holder must not be able to reset an admin's password or repoint their email/username,
since either would let them take over the account.
## Requirements
### Requirement: Only an admin may change who is an admin

Setting a user's role to `admin`, or changing the role of a user who is already an admin, SHALL be
permitted only when the acting user is an admin. A non-admin who holds `:manage, :users` SHALL still
create and edit users and change roles among non-admin roles, but any such change that would grant or
remove the `admin` role SHALL be dropped, leaving the account's existing or default role. The role
selector SHALL NOT offer the `admin` option to a user who cannot grant it (and SHALL be disabled when a
non-admin edits an admin), except that the admin role stays listed when the edited user already holds it.

#### Scenario: A non-admin user manager cannot mint an admin account

- **WHEN** a non-admin holding `:manage, :users` submits a new user with role `admin`
- **THEN** the account is created without the `admin` role

#### Scenario: A non-admin user manager cannot promote an existing user to admin

- **WHEN** a non-admin holding `:manage, :users` updates an existing user with role `admin`
- **THEN** the user's role is not changed to `admin`

#### Scenario: A non-admin user manager cannot strip an existing admin

- **WHEN** a non-admin holding `:manage, :users` updates an admin with a non-admin role
- **THEN** the admin's role is unchanged

#### Scenario: A non-admin user manager can still change non-admin roles

- **WHEN** a non-admin holding `:manage, :users` submits a user with a non-admin role
- **THEN** the account receives that role

#### Scenario: An admin can still grant and change the admin role

- **WHEN** an admin submits a user with role `admin`, or changes an existing admin's role
- **THEN** the change is applied

#### Scenario: A malformed role parameter is ignored

- **WHEN** a user update submits a non-scalar `role` (for example a nested `user[role][x]` value)
- **THEN** the role is left unchanged and the request does not error

### Requirement: Only an admin may edit an admin's account

Changing an existing admin's password or recovery identifiers (email, username) SHALL be permitted only
when the acting user is an admin. A non-admin who holds `:manage, :users` SHALL still edit those fields on
non-admin accounts and on their own account, but any such change to another admin's account SHALL be
refused — dropped from the user form's permitted parameters, and rejected by the AJAX password endpoint.
The user form SHALL disable those inputs and hide the change-password action for anyone who cannot use
them.

#### Scenario: A non-admin user manager cannot reset an admin's password

- **WHEN** a non-admin holding `:manage, :users` submits a new password for an existing admin (through the
  user form or the AJAX password endpoint)
- **THEN** the admin's password is unchanged

#### Scenario: A non-admin user manager cannot change an admin's email

- **WHEN** a non-admin holding `:manage, :users` submits a new email for an existing admin
- **THEN** the admin's email is unchanged

#### Scenario: A non-admin user manager can still manage non-admin credentials and their own

- **WHEN** a non-admin holding `:manage, :users` resets a non-admin user's password, or changes their own
- **THEN** the change is applied

#### Scenario: An admin can still edit an admin's account

- **WHEN** an admin resets another admin's password or changes their email
- **THEN** the change is applied

