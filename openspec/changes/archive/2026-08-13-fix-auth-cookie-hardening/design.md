# Design

## D1. One options helper, applied everywhere the cookie is written

`cama_auth_cookie_options(value)` returns `{ value:, httponly: true, secure: request.ssl?, expires: 24h,
domain?: :all }`. Both write sites use it — `login_user` (with a remember-me `:expires` override) and
`session_back_to_parent` (restoring the impersonation parent) — so no write can forget the flags. The
cookie value keeps its `token&ua&ip` string shape, so the split-based reader (`cookie_split_auth_token`)
and the impersonation stash (`session[:parent_auth_token]`, read back with `.split('&').first`) are
unchanged.

## D2. Rotate the token on logout

`cama_logout_user` calls `cama_current_user&.cama_reset_auth_token!` before clearing the cookie.
`cama_reset_auth_token!` regenerates the unique `auth_token` and persists it with `update_column`
(no validations/callbacks — it must work for any account and must not trip the password-change token
regeneration). Because `cama_current_user` resolves the (now-rotated) token to find the user, and the
token is the only server-side session identifier, this both kills the just-cleared cookie and ends the
user's other sessions. That logout-everywhere behavior is the intended trade for closing the
copied-cookie replay; it is called out for upgraders.

## D3. Secure over SSL only

`secure: request.ssl?` marks the cookie `Secure` on HTTPS requests and leaves it unmarked on plain HTTP,
so local development over HTTP still receives the cookie. A test asserts both directions (Secure under
`https!`, not Secure over HTTP) so a future change to a blanket `secure: true` — which would silently
break HTTP dev — is caught.

## D4. Why not encrypt (see proposal "Out of scope")

Signing/encryption defends against forging or reading the cookie. The `auth_token` cannot be forged
(random, matched against the DB) and, once `HttpOnly`, cannot be read by page scripts; a stolen cookie
replays regardless of encryption. So encryption's marginal benefit did not justify reproducing Rails'
encrypted-cookie derivation in the `sign_in_as` test helper and reworking the impersonation stash, which
is security-critical (H6). The higher-value legs — HttpOnly, Secure, and server-side rotation — are what
this change ships.

## D5. Testing

`spec/requests/security/auth_cookie_hardening_spec.rb` asserts the login `Set-Cookie` is `HttpOnly`,
is `Secure` under `https!` but not over HTTP, and that the user's `auth_token` changes after logout
(the HttpOnly, Secure-over-SSL, and rotation checks fail on master). The full login / logout /
impersonation / forced-password-change suites are re-run to confirm the cookie rewrite and rotation
leave those flows intact.
