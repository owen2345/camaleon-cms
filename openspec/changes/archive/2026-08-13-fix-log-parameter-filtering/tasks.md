## 1. Branch

- [x] 1.1 Work on the shared `security/tier2-hardening` branch (bundled Tier-2 PR, one commit per finding)
- [x] 1.2 Confirm the triage verdict — ✅ legit: engine sets no `filter_parameters`; dummy host filters only `[:password]`, so `email_pass`/S3 keys log in the clear

## 2. Reproduce first

- [x] 2.1 Add `spec/lib/engine_filter_parameters_spec.rb`: build an `ActiveSupport::ParameterFilter` from the configured filters and assert credentials are redacted, benign settings are not
- [x] 2.2 Confirm the redaction example fails against the unfixed engine (stash the fix, run, restore)

## 3. Fix

- [x] 3.1 Append `%i[passw email_pass secret access_key]` to `config.filter_parameters` in an engine initializer (`+=`, preserving host filters)
- [x] 3.2 Confirm the reproduction passes and benign settings stay readable

## 4. Verification

- [x] 4.1 `bin/rubocop` on the touched files — no offenses (lint before specs)
- [x] 4.2 `bin/rspec spec/lib/engine_filter_parameters_spec.rb` — green
- [x] 4.3 `bin/brakeman --no-pager` — no new warnings
- [x] 4.4 `(cd spec/dummy && bin/rails zeitwerk:check)` — clean

## 5. Changelog and archive

- [x] 5.1 Add a `## Unreleased` **Security fix** entry: credential parameters are filtered from logs
- [x] 5.2 Archive the change on the branch before merge, committed as part of the PR (`docs/ai/workflows.md` Phase 4)
