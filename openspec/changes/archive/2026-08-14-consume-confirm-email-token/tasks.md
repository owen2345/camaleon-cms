# Tasks

## 1. Reproduce first

- [x] 1.1 Add `spec/requests/security/confirm_email_token_spec.rb`: a successful confirmation clears
  the token and the spent token no longer resolves the account
- [x] 1.2 Confirm the token survives against the unfixed action

## 2. Fix

- [x] 2.1 Clear `confirm_email_token` / `confirm_email_sent_at` on successful confirmation

## 3. Verification

- [x] 3.1 `bin/rubocop` on the touched files — no offenses
- [x] 3.2 `bin/rspec` on the reproduction spec — green
- [x] 3.3 Full-suite + brakeman + zeitwerk at bundle presentation time
- [x] 3.4 Changelog + archive at ship time
