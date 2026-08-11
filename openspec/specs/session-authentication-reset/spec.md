# session-authentication-reset Specification

## Purpose
Pin that the session is rotated at authentication boundaries so security-sensitive session state cannot
cross them. The admin impersonation feature stashes a restorable admin auth cookie in
`session[:parent_auth_token]`; without rotation that stash outlives the admin and can be handed to an
unrelated later user, escalating them to admin. A genuine sign-in and a logout each reset the session,
while impersonation — which legitimately relies on that stash within one authenticated session — keeps
working.
## Requirements
### Requirement: A genuine sign-in rotates the session

`login_user` SHALL reset the session on a genuine sign-in, discarding any prior session state before the
new identity is established. This drops a residual impersonation `parent_auth_token` left in a shared
browser and provides session-fixation protection. The impersonation path, which stashes that token
deliberately, SHALL be able to suppress this single rotation so the token it must restore survives.

#### Scenario: A stale impersonation token does not survive a fresh sign-in

- **WHEN** a session carries a `parent_auth_token` from an abandoned impersonation and a different,
  low-privileged user signs in with their own credentials in that session
- **THEN** the residual token is dropped, so a subsequent `GET /admin/logout` does not restore the
  previous admin's `auth_token` cookie

### Requirement: Logout rotates the session

`cama_logout_user` SHALL reset the session on logout so that no residual session state — including an
impersonation `parent_auth_token` — survives into a later session on the same browser.

#### Scenario: Logging out clears server-side session state

- **WHEN** a signed-in user logs out through `cama_logout_user`
- **THEN** the session is reset and carries no `parent_auth_token`

### Requirement: Impersonation still switches and returns

Rotating the session on sign-in SHALL NOT break impersonation. Switching into another user SHALL
authenticate the browser as that user. Ending the impersonation SHALL restore the impersonating admin's
own session ONLY after that admin re-authenticates: while a parent token is present, the ordinary
`GET /admin/logout` SHALL route to a confirmation that requires the parent admin's password — verified
against the account resolved from `session[:parent_auth_token]` — before the admin's session is restored.
A request that does not supply the correct password SHALL NOT restore the admin session, and the current
holder SHALL be able to log out of the impersonated session instead.

Failed password attempts at the confirmation SHALL feed the same brute-force counter as the admin login
form; once the counter passes the site's threshold, restoring SHALL additionally require solving a
captcha. The confirmation SHALL NOT disclose the parent admin's username to the session holder. A stash
that does not resolve to a user — or resolves to an account that cannot be password-authenticated —
SHALL end the session instead of restoring it or raising an error.

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

#### Scenario: Repeated wrong passwords engage the login throttle

- **WHEN** more wrong passwords than the site's `max_try_attack` threshold are submitted to the
  confirmation
- **THEN** the failures are counted by the same counter as the login form, and even the correct admin
  password does not restore the session unless the captcha is also solved

#### Scenario: A stash that cannot be re-authenticated ends the session

- **WHEN** the confirmation is reached but the stashed token no longer resolves to a user, or resolves to
  an account with no password digest
- **THEN** the impersonated session is logged out instead of restoring the admin or raising an error

