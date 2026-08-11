# Design

## D1. Re-authentication is the only complete fix

The H6 session-reset fix closed the residue that survived into an *unrelated later sign-in*. What remains
is an admin abandoning a session that is *actively impersonating*: the browser is authenticated as the
target and the session still carries the admin's stashed token. The session an attacker would find is
byte-for-byte identical to the one the legitimate admin holds — same `auth_token` cookie (the target's),
same session. So no identity-based check can distinguish "the admin who is impersonating" from "whoever
now holds the browser": during impersonation the current user *is* the target, so a check like
"current user == impersonated target" passes for an attacker too, and "current user == admin" is never
true. The only thing that separates the real admin from a session-grabber is a secret the admin knows —
their password. Re-authenticating the admin before restoring is therefore the only measure that actually
closes the escalation; a time-box would merely bound the window.

There is no remote variant to defend beyond this: a cross-site `GET /admin/logout` fired at an admin who
is mid-impersonation only returns the *admin* to admin in the *admin's own* browser — the attacker gains
nothing. This is a local/physical-access hardening.

## D2. Route the return through a confirmation; keep an explicit "log out" escape

`/admin/logout` does double duty: it ends a normal session, and — when a parent token is present — it
returns to the parent. The return half now requires the admin's password, which a bare GET cannot carry,
so `logout` redirects to a `back_to_parent` action that renders a password form (GET) and verifies it
(POST). Because the impersonated holder might instead want to simply end the session, the confirmation
offers "log out completely", which points back at `/admin/logout?full=1`; the `params[:full]` guard makes
that branch call `cama_logout_user` directly rather than looping back to the confirmation. A real logout
already resets the session (H6), so it clears the stash on the way out.

## D3. Resolve the parent from the stash and verify with `has_secure_password`

`cama_impersonation_parent_user` parses the stashed `parent_auth_token` and looks the user up exactly as
`cama_current_user` does (`current_site.users_include_admins.find_by(auth_token:)`). The `back_to_parent`
action verifies the submitted password against that user with `authenticate` (the model uses
`has_secure_password`). Only on success does it call `session_back_to_parent`, which keeps its existing
mechanics (replay the cookie, delete the stash, redirect). Confining the restore to this one
post-verification call site — and documenting `session_back_to_parent` as "call only after re-auth" —
keeps the security property with the flow that enforces it.

A stash that no longer resolves to a user (for example, the admin rotated their `auth_token` by changing
their password) cannot be returned to; that case logs the impersonated session out rather than leaving a
dead-end form.
