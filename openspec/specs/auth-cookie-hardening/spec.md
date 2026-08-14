# auth-cookie-hardening Specification

## Purpose
Protect the admin auth cookie, whose value is a bearer token that authenticates the user. The token
must not be readable by page scripts, must not travel in the clear, and must not remain usable after the
user logs out.
## Requirements
### Requirement: The auth cookie is HttpOnly and Secure over SSL

The auth cookie SHALL be set with `HttpOnly`, so page scripts cannot read the bearer token, and with
`Secure` on an SSL request, so it is not sent over plain HTTP. Over a non-SSL request it SHALL NOT be
marked `Secure`, so development over HTTP continues to work. Every path that writes the auth cookie
SHALL use the same hardened options — including the re-issue that keeps a user signed in after they
change their own password — so no path re-issues a bare cookie.

#### Scenario: Login sets an HttpOnly cookie

- **WHEN** a user logs in
- **THEN** the auth cookie is set with the `HttpOnly` attribute

#### Scenario: The cookie is Secure only over SSL

- **WHEN** a user logs in over an SSL request
- **THEN** the auth cookie is set with the `Secure` attribute
- **AND** over a plain-HTTP login the auth cookie is not marked `Secure`

#### Scenario: Re-issuing the cookie on a password change keeps the hardening

- **WHEN** a user changes their own password and the session is kept alive by re-issuing the cookie
- **THEN** the re-issued auth cookie is `HttpOnly` (and `Secure` over SSL), not a bare cookie

### Requirement: Logout rotates the server-side token

Logging out SHALL rotate the user's server-side `auth_token`, so a cookie copied before logout can no
longer authenticate. Because the token is a single per-user value, this SHALL end the user's other
sessions as well. The rotation SHALL be skipped while an impersonation is active (a stashed parent
token is present): the current user is then the impersonated user, not the admin ending the session,
so rotating their token would wrongly end the innocent user's sessions.

#### Scenario: The token changes on logout

- **WHEN** a logged-in user logs out
- **THEN** the user's stored `auth_token` is different from the one the session was using

#### Scenario: A full logout during impersonation does not rotate the impersonated user's token

- **WHEN** an admin impersonating another user performs a full logout of the impersonated session
- **THEN** the impersonated user's `auth_token` is unchanged, while an ordinary (non-impersonation)
  logout still rotates it

