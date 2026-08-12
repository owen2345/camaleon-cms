## 1. Branch

- [x] 1.1 Create branch `security/login-brute-force-throttle` off the latest `master` and announce it
- [x] 1.2 Confirm the triage verdict — ✅ legit; the login gate is a per-session counter (cookie-drop bypass, no lockout) and the `attack` plugin keys on the session id + writes a DB row per request

## 2. Reproduce first

- [x] 2.1 Add `spec/requests/security/login_brute_force_throttle_spec.rb`: dropping the session cookie must not reset the gate; an IP must be 429-locked after the hard threshold
- [x] 2.2 Add `attack/attack_helper_spec` cases: the throttle key is the client IP, and inserts stop once banned
- [x] 2.3 Confirm all fail against the unfixed code (stash the fix, run, restore)

## 3. Fix

- [x] 3.1 Track the attack counter per client IP in `Rails.cache` (session OR IP over `max_try_attack`); keep the per-session counter
- [x] 3.2 Add the hard lockout (`login_lockout_attempts`, default 4× soft) to `login_post` and `back_to_parent` — 429 + self-expiring cooldown
- [x] 3.3 Re-key the `attack` plugin throttle/ban on `request.remote_ip`; inserts stop once over the limit
- [x] 3.4 Add the `too_many_attempts` i18n string; clear per-IP counters between examples in `rails_helper`
- [x] 3.5 Confirm the reproductions now pass

## 4. Cover the unchanged paths

- [x] 4.1 Update the captcha helper / concern test harnesses to provide `current_site.id` + `request` (the IP counter's new deps)
- [x] 4.2 Run the captcha attack-counter spec, session/impersonation request specs, and the admin sign-in feature spec — green

## 5. Verification

- [x] 5.1 `bin/rspec` on the touched specs and `spec/requests/security/` — green
- [x] 5.2 `bin/rubocop` on touched files — no offenses
- [x] 5.3 `bin/brakeman --no-pager` — no new warnings
- [x] 5.4 `(cd spec/dummy && bin/rails zeitwerk:check)` — clean

## 6. Changelog and archive

- [x] 6.1 Add a `## Unreleased` **Security fix** entry: per-IP login throttle (captcha + hard lockout) and the attack-plugin re-key
- [ ] 6.2 Archive the change on the branch before merge, committed as part of the PR (`docs/ai/workflows.md` Phase 4)
