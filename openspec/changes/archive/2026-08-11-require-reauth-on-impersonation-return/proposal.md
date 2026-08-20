## Why

Ending impersonation restores the impersonating admin's session by replaying the admin auth cookie
stashed in `session[:parent_auth_token]`. `session_back_to_parent` did this for any signed-in holder of
that session with no proof of admin identity. Because the impersonated session an admin holds is
byte-for-byte identical to one they abandon on a shared browser, no server-side identity check can tell
the admin apart from a later occupant — so an admin who walks away mid-impersonation lets the next person
restore the admin account by clicking the ordinary Logout link. This is the H6 residual (local access; no
remote escalation).

### Triage verdict: legit

Reproduced against master (`spec/requests/security/impersonation_return_reauth_spec.rb`): after
impersonating, a bare `GET /admin/logout` hands the holder the admin's `auth_token` cookie. The
reproduction fails without the fix (confirmed).

## What Changes

- Ending impersonation now re-authenticates the admin. `GET /admin/logout` while a parent token is present
  redirects to a confirmation (`back_to_parent`) instead of restoring; the admin must POST their own
  password — verified against the parent account resolved from the stash — before `session_back_to_parent`
  runs.
- The confirmation also offers "log out completely" (`GET /admin/logout?full=1` → `cama_logout_user`), so
  the current holder can end the impersonated session without knowing the admin's password.
- A wrong or missing password re-renders the form and leaves impersonation active, so the real admin can
  retry; the admin session is not restored.
- New `cama_impersonation_parent_user` resolves the parent admin from `session[:parent_auth_token]` (the
  same lookup `cama_current_user` uses).

## Out of scope

- **Throttling the re-auth endpoint.** Guessing the admin's password through `back_to_parent` shares the
  login form's lack of brute-force protection (audit findings H1/H2); rate limiting is tracked there and
  not added here. Re-auth still raises the bar from a single click to knowing the admin's password.
