## Why

The captcha is bypassable and a DoS vector. `GET /captcha?len=` passes an attacker-controlled length
straight into image generation, so `?len=100000` renders a huge image and stashes a huge string in the
session (unauthenticated worker memory/CPU exhaustion — H4), while `?len=1` shrinks the answer to one of
26 letters. Worse, every issued answer was appended to `session[:cama_captcha]` and never cleared, and
verification accepted any value still in that list — so loading `?len=1` a couple dozen times filled the
list with every letter and any single-letter guess then passed. A blank submission matched too. These are
audit findings H3 (captcha fully bypassable) and H4 (unauthenticated memory exhaustion).

### Triage verdict: legit

Reproduced against master (`captcha_hardening_spec`, `captcha_helper_spec`): `?len=64` stores a 64-char
answer, three loads accumulate three answers, and a stale or blank value still verifies. All fail without
the fix (confirmed by stashing it).

## What Changes

- `cama_captcha_build` clamps the requested length to a safe range (4–8, default 5) before generating, so
  `?len=` can neither exhaust memory nor shrink the alphabet. Applied in both copies of the method — the
  controller concern that serves `/captcha` and the helper mixed into the runtime/view stack.
- The session holds a single active challenge: each build **replaces** `session[:cama_captcha]` instead of
  appending, so only the currently displayed captcha can verify.
- `cama_captcha_verified?` rejects a blank submission, matches only that single active challenge, and
  **consumes** it on success (single-use, no replay). `captcha_verify_if_under_attack` now calls it once so
  the attack-counter reset still fires after a genuine solve.

## Notes for upgraders

- Captchas are now single-use and bound to the current image. A solved captcha will not verify a second
  time, and a re-rendered form issues a fresh challenge. Any integration that reused one captcha answer
  across submissions must request a new image per attempt.

## Out of scope

- **Brute-force throttling / rate limiting** of the login and captcha endpoints (audit findings H1/H2),
  which is a separate change.
