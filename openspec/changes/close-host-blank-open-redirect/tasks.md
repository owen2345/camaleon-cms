## 1. Branch

- [x] 1.1 Create branch `security/harden-safe-redirect-url` off the latest `master` and announce it
- [x] 1.2 Confirm the triage verdict — ✅ legit; `safe_redirect_url` returns host-blank URLs (`///evil.com`, `https:evil.com`) unchanged, and `login_user`'s explicit `redirect_url` arg skips the host check

## 2. Reproduce first

- [x] 2.1 Extend `spec/requests/security/open_redirect_session_spec.rb`: host-blank `return_to` values on login/logout fall back to the safe default; an off-site `redirect_url` set by an `after_login` hook falls back to the dashboard
- [x] 2.2 Confirm the new examples fail against the unfixed code (stash the fix, run, restore)

## 3. Fix

- [x] 3.1 `safe_redirect_url` follows a host-blank destination only when it is a single-slash local path (reject scheme, `//`/`\` forms, and `%2f`/`%5c` encodings)
- [x] 3.2 `login_user` routes its explicit `redirect_url` argument through `safe_redirect_url`
- [x] 3.3 Confirm the reproductions now pass

## 4. Cover the unchanged paths

- [x] 4.1 Run the existing same-host / relative / logout `return_to` cases — still followed
- [x] 4.2 Run the full `spec/requests/security/` suite and the admin sign-in feature spec — green

## 5. Verification

- [x] 5.1 `bin/rspec` on the touched spec and `spec/requests/security/` — green
- [x] 5.2 `bin/rubocop` on touched files — no offenses
- [x] 5.3 `bin/brakeman --no-pager` — no new warnings
- [x] 5.4 `(cd spec/dummy && bin/rails zeitwerk:check)` — clean

## 6. Changelog and archive

- [x] 6.1 Add a `## Unreleased` **Security fix** entry: host-blank open redirect closed and the explicit `login_user` redirect argument host-checked
- [ ] 6.2 Archive the change on the branch before merge, committed as part of the PR (`docs/ai/workflows.md` Phase 4)
