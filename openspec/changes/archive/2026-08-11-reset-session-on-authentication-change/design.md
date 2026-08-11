# Design

## D1. Rotate the session at the authentication boundary, not the auth cookie

The escalation exists because `session[:parent_auth_token]` — a raw, restorable admin auth cookie — can
outlive the admin who created it and be restored into an unrelated later session. The session is the
wrong place for state that must never cross an authentication boundary, so the fix rotates the session at
exactly those boundaries: `reset_session` on a genuine sign-in and on logout. Rotating on sign-in also
gives the login flow standard session-fixation protection (a pre-auth session id is never reused for an
authenticated identity); rotating on logout closes the "session never rotated on logout" low-severity
item the audit tracks alongside H6.

The auth cookie is deliberately left untouched here. Its transport hardening (`HttpOnly`/`Secure`) and
rotating the `auth_token` value on logout are finding M3; folding them in would widen the change beyond
H6.

## D2. Preserve impersonation by resetting before the stash, not after

`session_switch_user` sets `session[:parent_auth_token]` and then calls `login_user`. If `login_user`
unconditionally reset the session, it would wipe the token that was just stashed and break the "return to
parent" flow. Two options preserve impersonation:

1. Stash the parent token *after* `login_user` runs.
2. Reset the session in `session_switch_user`, stash the token, then suppress `login_user`'s own reset.

Option 2 is used. It keeps a single, explicit rule — "a genuine sign-in rotates the session" — and makes
the impersonation path state its exception locally (`rotate_session: false`) rather than depending on the
ordering of a redirect-issuing helper. `cookies[:auth_token]` (the admin's token) is captured before the
reset; cookies are a separate jar from the session, so the reset does not disturb it.

`session_back_to_parent` is unchanged: it already `session.delete(:parent_auth_token)` after restoring, so
the return path leaves no residue.

## D3. `rotate_session:` is a backward-compatible keyword

`login_user(user, remember_me = false, redirect_url = nil)` gains a `rotate_session: true` keyword. All
existing positional callers — in-repo and in downstream plugins/themes — keep working unchanged and get
the safe default (rotate). Only the impersonation path passes `false`.

One behavior change follows for downstream code: because a genuine sign-in now resets the session, data
placed in the session during a `user_before_login`/`after_login` hook (or otherwise before `login_user`)
does not survive the sign-in. In-repo flows do not rely on this — the captcha attack counter is only
reset on success and then discarded, the installer's welcome marker is set on a request that does not call
`login_user`, and `return_to` is a cookie, not session — so the change is limited to the security fix. The
changelog notes the hook caveat for downstream authors.
