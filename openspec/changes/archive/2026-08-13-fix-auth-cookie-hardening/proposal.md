## Why

The `auth_token` cookie was set in the plain jar with no `HttpOnly` or `Secure` flag, and logout deleted
the cookie without rotating the server-side token. So the bearer token was readable by JavaScript
(XSS → account takeover), sent in the clear over plain HTTP, and a cookie copied before logout stayed
valid indefinitely afterward. Audit finding M3.

### Triage verdict: legit

Reproduced in `spec/requests/security/auth_cookie_hardening_spec.rb`: on master the login `Set-Cookie`
carries neither `HttpOnly` nor (over SSL) `Secure`, and the user's `auth_token` is unchanged after
logout. All three fail without the fix (stash-verified).

## What Changes

- The auth cookie is written through one options helper that sets `HttpOnly: true` and
  `Secure: request.ssl?`, applied at every write site (login and impersonation return).
- Logout rotates the user's `auth_token` (`User#cama_reset_auth_token!`), so a cookie copied before
  logout can no longer authenticate.

## Notes for upgraders

- **Logout now signs the user out on all their devices.** The `auth_token` is a single per-user value
  and the only server-side session identifier, so rotating it on logout necessarily ends every session
  for that user. This is the intended, more-secure posture.
- The cookie is `Secure` only over an SSL request (`request.ssl?`). Behind an SSL-terminating proxy,
  ensure forwarded-proto headers are trusted so the flag applies.

## Out of scope — cookie encryption (deliberate)

The cookie stays in the plain jar (not signed/encrypted). The `auth_token` is a random bearer credential
matched against the database: a stolen cookie authenticates whether or not it is encrypted, and it
cannot be forged. `HttpOnly` closes the XSS read vector and `Secure` closes the network vector — the two
ways the token actually leaks — so encryption adds little here, while it would force the sign-in test
helpers to reproduce Rails' cookie encryption and would touch the security-critical impersonation
stash/restore. Left out on purpose; can be revisited if a defense-in-depth pass wants it.
