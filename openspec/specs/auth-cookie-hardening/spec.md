# auth-cookie-hardening Specification

## Purpose
Protect the admin auth cookie, whose value is a bearer token that authenticates the user. The token
must not be readable by page scripts, must not travel in the clear, and must not remain usable after the
user logs out.
## Requirements
### Requirement: The auth cookie is HttpOnly and Secure over SSL

The auth cookie SHALL be set with `HttpOnly`, so page scripts cannot read the bearer token, and with
`Secure` on an SSL request, so it is not sent over plain HTTP. Over a non-SSL request it SHALL NOT be
marked `Secure`, so development over HTTP continues to work.

#### Scenario: Login sets an HttpOnly cookie

- **WHEN** a user logs in
- **THEN** the auth cookie is set with the `HttpOnly` attribute

#### Scenario: The cookie is Secure only over SSL

- **WHEN** a user logs in over an SSL request
- **THEN** the auth cookie is set with the `Secure` attribute
- **AND** over a plain-HTTP login the auth cookie is not marked `Secure`

### Requirement: Logout rotates the server-side token

Logging out SHALL rotate the user's server-side `auth_token`, so a cookie copied before logout can no
longer authenticate. Because the token is a single per-user value, this SHALL end the user's other
sessions as well.

#### Scenario: The token changes on logout

- **WHEN** a logged-in user logs out
- **THEN** the user's stored `auth_token` is different from the one the session was using

