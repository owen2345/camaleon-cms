## Why

`Admin::SessionsController#forgot` answered a reset request differently depending on whether the email
matched an account: a match redirected with a success notice; a miss re-rendered with a distinct "email
not found" error. That is a user-enumeration oracle. It also re-sent a reset email on every request, so
an attacker who knows an address could use the endpoint to flood that inbox. Audit finding M13.

### Triage verdict: legit

Reproduced in `spec/requests/security/forgot_password_enumeration_spec.rb`: on master an unknown email
renders with `flash[:error]` while a known email redirects with `flash[:notice]`, and two requests send
two emails. Both fail without the fix (stash-verified).

## What Changes

- `forgot` always responds with the same neutral notice ("If an account matches that email, a password
  reset link has been sent.") and the same redirect, whether or not the email exists.
- A reset email is sent at most once per account per cooldown window
  (`PASSWORD_RESET_EMAIL_COOLDOWN`, 5 minutes); within the window the request is still accepted and
  answered identically but sends nothing. The already-issued token stays valid for its 2h lifetime.

## Notes for upgraders

- The forgot-password page no longer tells the requester whether the email is registered; it always
  shows the neutral confirmation. A new locale key `password_reset_requested` is added (English;
  other locales fall back until translated).

## Out of scope

- The token validation / single-use / expiry path (already fixed, #1248).
- Global rate-limiting of the endpoint by IP (the per-account cooldown is the targeted mail-bomb fix;
  the login throttle already covers credential-guessing).
