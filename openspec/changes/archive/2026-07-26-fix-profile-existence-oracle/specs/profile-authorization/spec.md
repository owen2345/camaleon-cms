## MODIFIED Requirements

### Requirement: Profile access is authorized
The system SHALL enforce authorization on the `GET /admin/profile` endpoint. A user SHALL only see another user's profile if they are viewing their own profile (`params[:user_id]` matches the current user's ID) OR they have `:manage` permission on `:users` (admin role).

The authorization decision SHALL be derived from the request parameter alone and SHALL be made before the target user is loaded, so that the response to an unauthorized caller does not depend on whether the requested user exists.

#### Scenario: Self-profile without user_id
- **WHEN** an authenticated user visits `/admin/profile` without a `user_id` parameter
- **THEN** the system renders the current user's own profile

#### Scenario: Self-profile with matching user_id
- **WHEN** an authenticated user visits `/admin/profile?user_id=CURRENT_USER_ID`
- **THEN** the system renders the current user's own profile

#### Scenario: Admin views another user's profile
- **WHEN** an admin user visits `/admin/profile?user_id=OTHER_USER_ID`
- **THEN** the system renders the other user's profile

#### Scenario: Non-admin tries to view another user's profile
- **WHEN** a non-admin user visits `/admin/profile?user_id=OTHER_USER_ID`
- **THEN** the system denies access and redirects to the admin dashboard

#### Scenario: Non-admin tries to view another user's profile (unauthorized response)
- **WHEN** a non-admin user sends a request to `/admin/profile?user_id=OTHER_USER_ID`
- **THEN** the system returns an HTTP 403 Forbidden or redirects to the dashboard with an error message

#### Scenario: Denial does not reveal whether the target user exists
- **WHEN** a non-admin user requests `/admin/profile` with a `user_id` that is not their own — whether it identifies an existing user, a nonexistent user, or a non-numeric value
- **THEN** the system denies access in every case with the same HTTP status and the same redirect target, disclosing no difference between them
- **AND** the system does not query for the target user before denying access

## ADDED Requirements

### Requirement: Unresolvable profile targets are handled gracefully
The system SHALL NOT raise an unhandled exception when the `user_id` supplied to `GET /admin/profile` does not resolve to a user visible to the current site. This applies to nonexistent IDs, IDs of deleted users, and non-numeric values.

Note: whether a user of a *different* site resolves is governed by the `users_share_sites` system setting, not by this capability. Under the shipped default (`true`), `Site#users` spans all sites, so such an ID resolves normally and is covered by the ordinary "admin views another user" scenario.

#### Scenario: Authorized user requests a nonexistent user
- **WHEN** a user authorized to manage users visits `/admin/profile?user_id=NONEXISTENT_ID`
- **THEN** the system redirects to the admin path with the "not found user" error message
- **AND** the system does not return a 500 response

#### Scenario: Authorized user supplies a non-numeric user_id
- **WHEN** a user authorized to manage users visits `/admin/profile?user_id=abc`
- **THEN** the system redirects to the admin path with the "not found user" error message
- **AND** the system does not return a 500 response
