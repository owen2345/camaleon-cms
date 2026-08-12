# Design

## D1. Put the per-IP signal in the existing captcha counter

The login gate already exists — `captcha_verify_if_under_attack('login')` in the controller and
`cama_captcha_tags_if_under_attack('login')` in the login/re-auth views — but its "under attack" test read
only a per-session counter, which the client controls. Rather than add a parallel gate (which would risk a
form-shows-no-captcha / submit-requires-captcha mismatch), the fix teaches the existing counter a second,
server-side signal: `cama_captcha_increment_attack`/`reset_attack` also maintain a per-IP counter in
`Rails.cache`, and `cama_captcha_under_attack?` is true when **either** the session or the IP counter is
over `max_try_attack`. Because both the controller check and the view helper call the same predicate, the
form and the submission agree automatically, and dropping the session cookie no longer clears the gate.

The IP counter is keyed `cama_captcha_attack:<site>:<ip>:<form-key>` and written with a rolling TTL
(`CAMA_ATTACK_WINDOW`), so a burst of failures rolls off after the window of inactivity. The per-session
counter is kept (unchanged) so existing behaviour and its spec are preserved; it is now the weaker of the
two signals.

## D2. Hard lockout lives in the controller

Requiring a captcha is a soft gate — an attacker who can solve captchas is only slowed. The controller adds
a hard lockout: once the per-IP counter reaches `login_lockout_attempts` (default `max_try_attack * 4`),
`login_post` and `back_to_parent` refuse every attempt with HTTP 429 before touching credentials, and
re-count the blocked attempt so the TTL keeps refreshing while the attacker keeps trying (they stay locked
until they stop for the window). It renders the action's own template (login form / re-auth form) so the
"log out completely" escape hatch on the re-auth page still works.

The threshold is per IP, never per account: a per-account lockout would let an attacker lock a known admin
out on purpose. Two thresholds (soft = captcha, hard = lockout) keep shared-IP users usable — they solve a
captcha long before anyone is locked out.

## D3. Re-key the attack plugin and bound its writes

The `attack` plugin counted requests in `plugins_attacks` keyed on `cama_get_session_id`. A cookieless
request presented a fresh id each time, so the per-key count never accumulated: the throttle never tripped
and `query.create` ran on every request — an unbounded unauthenticated write. Keying `browser_key` and the
ban cache on `request.remote_ip` makes the count accumulate, trip the limit, and (once banned) stop
inserting. A distributed attacker still writes one row per IP per window; the hourly cleanup bounds total
growth, as before.

## D4. Operational caveats

Cache-based throttling only holds across workers with a shared store; `:memory_store` is per-process, so a
multi-worker deployment should use Redis/memcached (the `attack` plugin already assumed `Rails.cache`).
`request.remote_ip` honours the app's trusted-proxy configuration; behind a misconfigured proxy that
collapses all clients to one IP, the throttle would over-trigger — a deployment concern, not a code one.

## D5. Testing

`login_brute_force_throttle_spec` simulates the cookieless attacker by dropping the `_dummy_session`
cookie between requests (the client IP is constant across request specs), proving the gate survives a
session reset and that an IP is 429-locked after the hard threshold. `attack/attack_helper_spec` drives the
real throttle against a created `plugins_attacks` table and asserts the stored `browser_key` is the IP and
that inserts stop once banned. Per-IP cache counters are cleared before each example in `rails_helper` so
throttle state never leaks between the many request specs that log in from 127.0.0.1.
