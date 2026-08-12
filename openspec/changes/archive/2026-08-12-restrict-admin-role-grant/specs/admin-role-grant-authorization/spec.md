## Purpose

Pin that the `admin` role — the role `User#admin?` tests, which `Ability` maps to `can :manage, :all` —
can be granted or removed only by an existing admin. Holding `:manage, :users` lets a user manage accounts
and change non-admin roles, but must not be a path to minting an admin (escalating to superadmin) or to
stripping an existing admin.

## ADDED Requirements

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
