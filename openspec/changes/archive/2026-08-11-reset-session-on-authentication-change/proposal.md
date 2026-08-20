## Why

`session_switch_user` stashes the admin's raw auth cookie in `session[:parent_auth_token]`, and
`session_back_to_parent` restores it on `/admin/logout` for any signed-in user. A genuine sign-in never
rotated the session and logout never cleared it, so that stash outlived the admin: on a shared browser a
different low-privileged user who signs in with their own credentials inherits the residual token and is
handed the admin's cookie on logout — escalating to admin. This is audit finding **H6**.

### Triage verdict: legit

Per `docs/ai/workflows.md` Phase 2A. Reproduced against unfixed master: impersonate a user, then sign in
as an unrelated low-privileged user in the same session and hit `/admin/logout` — the resulting
`auth_token` cookie is the admin's. The reproduction fails without the fix (confirmed by stashing it).

## What Changes

- `login_user` rotates the session (`reset_session`) on a genuine sign-in, dropping any stale session
  state — notably a residual impersonation `parent_auth_token` — before it establishes the new identity.
  A new `rotate_session:` keyword (default `true`) lets the impersonation path opt out.
- `session_switch_user` resets the session first, then stashes the admin's token and calls
  `login_user(..., rotate_session: false)`, so impersonation starts from a clean session and the token it
  must restore later is not wiped by `login_user`'s own rotation.
- `cama_logout_user` resets the session on logout, so no `parent_auth_token` survives to a later login.
- A request spec proves the abandoned-impersonation → fresh low-priv login → logout escalation no longer
  occurs, and that normal impersonation (switch, then return to the parent session) still works.

## Out of scope

- **Auth-cookie hardening (M3):** setting `HttpOnly`/`Secure` on the `auth_token` cookie and rotating the
  `auth_token` value itself on logout are a separate finding (M3) and are unchanged here. This change
  rotates the *session*, not the auth cookie.
