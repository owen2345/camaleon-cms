## MODIFIED Requirements

### Requirement: Impersonation still switches and returns

Rotating the session on sign-in SHALL NOT break impersonation. Switching into another user SHALL
authenticate the browser as that user. Ending the impersonation SHALL restore the impersonating admin's
own session ONLY after that admin re-authenticates: while a parent token is present, the ordinary
`GET /admin/logout` SHALL route to a confirmation that requires the parent admin's password — verified
against the account resolved from `session[:parent_auth_token]` — before the admin's session is restored.
A request that does not supply the correct password SHALL NOT restore the admin session, and the current
holder SHALL be able to log out of the impersonated session instead.

#### Scenario: An admin impersonates a user

- **WHEN** an admin impersonates a user
- **THEN** the browser is authenticated as that user

#### Scenario: Ending impersonation returns the admin to their own session

- **WHEN** the admin ends the impersonation while the parent token is present and submits their own
  password to the confirmation
- **THEN** the admin's own `auth_token` cookie is restored and the stashed parent token is cleared

#### Scenario: The plain Logout link does not restore the admin without re-auth

- **WHEN** the holder of an abandoned impersonation follows `GET /admin/logout`
- **THEN** they are routed to the re-authentication confirmation and the admin's `auth_token` cookie is
  not restored

#### Scenario: A wrong password does not restore the admin and keeps impersonation active

- **WHEN** an incorrect password is submitted to the confirmation
- **THEN** the admin's session is not restored and the parent token remains stashed so the real admin can
  retry

#### Scenario: The holder can log out of the impersonated session completely

- **WHEN** the holder chooses to log out completely (`GET /admin/logout?full=1`)
- **THEN** the impersonated session is ended and no parent token survives
