## Why

Admin login has no real brute-force protection. The "under attack" decision is a per-session counter
(`session["cama_captcha_login"]`), so an attacker who sends login POSTs without a session cookie always
looks fresh — the counter stays 0, the captcha is never required, and passwords are guessed without limit
(H1). The bundled `attack` plugin cannot help: it only registers `front_before_load`, so it never runs on
admin login, and it keys its own throttle/ban on the session id too, so the same cookie-drop bypasses it —
while it inserts a DB row on essentially every request, an unbounded unauthenticated write (H2).

### Triage verdict: legit

Reproduced against master (`login_brute_force_throttle_spec`, `attack/attack_helper_spec`): dropping the
session cookie resets the login gate (a correct password then logs straight in), no IP lockout exists, and
the attack throttle keys on the session id. All fail without the fix (confirmed by stashing it).

## What Changes

- The captcha attack counter is now tracked per client IP (in `Rails.cache`) as well as per session.
  `cama_captcha_under_attack?` triggers on either, so dropping the session cookie no longer clears the
  captcha requirement — the existing gate, and the login/re-auth forms, become effective server-side (H1).
  Keyed per `(site, IP, form-key)`, with a rolling TTL window.
- Admin login and the impersonation re-auth endpoint gain a hard lockout: past a higher per-IP threshold
  (default 4× the captcha threshold, configurable via `login_lockout_attempts`), every attempt from that
  IP is refused with HTTP 429 for a self-expiring cooldown, regardless of credentials or captcha.
- The `attack` plugin keys its throttle and ban on `request.remote_ip` instead of the session id, so a
  cookieless request is still counted; once an IP is over the limit the per-request DB insert stops (H2).

## Notes for upgraders

- Brute-force counters are per client IP now. Behind a shared IP (corporate NAT, mobile carrier) a captcha
  may appear after enough failed logins from anyone on that IP; the hard lockout only triggers at a much
  higher threshold. Tune per site with `max_try_attack` (captcha) and `login_lockout_attempts` (lockout).
- The per-IP counters live in `Rails.cache`. Use a shared cache store (Redis/memcached) in production so
  the throttle holds across worker processes; `:memory_store` is per-process.

## Out of scope

- A distributed attacker (many IPs) is slowed but not stopped by per-IP limits; per-account lockout was
  deliberately not added (it would let an attacker lock out a known admin). Enumeration/timing/password
  policy (M13/M14/M15) are separate.
