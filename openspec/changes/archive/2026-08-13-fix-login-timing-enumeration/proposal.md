## Why

`Admin::SessionsController#login_post` verified the password with `@user&.authenticate(...)`. When the
username does not exist `@user` is nil and `&.` short-circuits, so no bcrypt comparison runs and the
response returns markedly faster than for a real username with a wrong password. That timing difference
is an oracle for enumerating valid usernames. Audit finding M14.

### Triage verdict: legit

Reproduced in `spec/requests/security/login_timing_enumeration_spec.rb`: a missing-username login runs
no `BCrypt::Password#is_password?` comparison on master (the failed-login user is built, which only
*creates* a digest, never compares one). Fails without the fix (stash-verified).

## What Changes

- `login_post` verifies via `cama_password_matches?(user, password)`, which authenticates a real user
  and, when the user is missing, spends one bcrypt comparison against a precomputed dummy digest before
  returning false. A missing username now costs about the same as a wrong password.

## Notes for upgraders

- None. Login behavior is unchanged for valid and invalid credentials alike; only the response *timing*
  of an unknown username is equalized.

## Out of scope

- Rate-limiting/lockout (already shipped for login, H1/H2).
- Username enumeration through other endpoints (registration availability checks, if any) — not in this
  finding.
