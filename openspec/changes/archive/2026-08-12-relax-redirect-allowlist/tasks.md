## 1. Design

- [x] 1.1 Confirm the approach with the maintainer: allowlist **and** explicit opt-in (both), fail-closed

## 2. Implement

- [x] 2.1 `safe_redirect_url`: move the `http`/`https` scheme check ahead of the host decision; follow an off-site host that is allowlisted or vouched via `allow_external`
- [x] 2.2 `cama_redirect_allowed_hosts` (from `redirect_allowed_hosts` option + `safe_redirect_hosts` hook) and `cama_redirect_host_allowed?` (case-insensitive, exact host)
- [x] 2.3 `cama_safe_redirect` centralizing vet + fallback + version-gated `allow_other_host`; route the four session redirect sites through it
- [x] 2.4 `login_user` `allow_external:` keyword; plumb the `after_login`/`user_registered` `r[:allow_external_redirect]` opt-in

## 3. Tests

- [x] 3.1 `spec/requests/security/redirect_allowlist_spec.rb`: allowlisted host followed via option and via hook (case-insensitive, comma list)
- [x] 3.2 Non-allowlisted host and a no-opt-in off-site destination still fall back to the safe default
- [x] 3.3 `allow_external` opt-in followed for `after_login` and `user_registered` (off-site, no 500)
- [x] 3.4 Neither the allowlist nor the opt-in can carry a non-`http` scheme (`javascript://allowlisted-host`)

## 4. Verify

- [x] 4.1 `bin/rubocop` on touched files — no offenses
- [x] 4.2 `bin/rspec spec/requests/security spec/requests/admin/sessions` — green
- [x] 4.3 `bin/brakeman --no-pager` — no new warnings
- [x] 4.4 `(cd spec/dummy && bin/rails zeitwerk:check)` — clean

## 5. Docs and archive

- [x] 5.1 CHANGELOG **Notes for upgraders**: `redirect_allowed_hosts` option, `safe_redirect_hosts` hook, `allow_external_redirect` opt-in
- [x] 5.2 Archive the change on the branch before merge (`docs/ai/workflows.md` Phase 4)
