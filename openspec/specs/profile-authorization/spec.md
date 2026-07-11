## Purpose

Define authorization requirements for the admin profile endpoint (`GET /admin/profile`).

## Requirements

### Requirement: Profile access is authorized
The system SHALL enforce authorization on the `GET /admin/profile` endpoint. A user SHALL only see another user's profile if they are viewing their own profile (`params[:user_id]` matches the current user's ID) OR they have `:manage` permission on `:users` (admin role).

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
