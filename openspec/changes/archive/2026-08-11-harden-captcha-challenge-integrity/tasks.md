## 1. Branch

- [x] 1.1 Create branch `security/captcha-clamp-and-single-challenge` off the latest `master` and announce it
- [x] 1.2 Confirm the triage verdict — ✅ legit; `?len=` is unbounded (H4) and the accumulated, never-consumed challenge list plus a shrinkable length made the captcha bypassable (H3)

## 2. Reproduce first

- [x] 2.1 Add `spec/requests/security/captcha_hardening_spec.rb`: `?len=64` stores a bounded answer, `?len=1` is floored, three loads keep one active challenge
- [x] 2.2 Add `#cama_captcha_verified?` cases to `spec/helpers/camaleon_cms/captcha_helper_spec.rb`: consume-on-success (no replay) and blank rejection
- [x] 2.3 Confirm all fail against the unfixed code (stash the fix, run, restore)

## 3. Fix

- [x] 3.1 Clamp the requested length to 4–8 (default 5) in both `cama_captcha_build` copies
- [x] 3.2 Replace (never append) `session[:cama_captcha]` so only the current challenge verifies
- [x] 3.3 `cama_captcha_verified?` rejects blank, matches the single challenge, and consumes it on success; `captcha_verify_if_under_attack` calls it once
- [x] 3.4 Confirm the reproductions now pass

## 4. Cover the unchanged paths

- [x] 4.1 Add a request example proving a legitimate `POST /admin/register` still succeeds with the correct current captcha
- [x] 4.2 Update the register feature spec (remove the now-undeterministic browser happy-path; point to the request spec); keep the wrong-captcha example
- [x] 4.3 Run the session/captcha concern specs, contact-form spec and the full `spec/requests/security/` suite — green

## 5. Verification

- [x] 5.1 `bin/rspec` on the touched specs and `spec/requests/security/` — green
- [x] 5.2 `bin/rubocop` on touched files — no offenses
- [x] 5.3 `bin/brakeman --no-pager` — no new warnings
- [x] 5.4 `(cd spec/dummy && bin/rails zeitwerk:check)` — clean

## 6. Changelog and archive

- [x] 6.1 Add a `## Unreleased` **Security fix** entry: the captcha length is clamped and only a single, single-use challenge verifies
- [x] 6.2 Archive the change on the branch before merge, committed as part of the PR (`docs/ai/workflows.md` Phase 4)
