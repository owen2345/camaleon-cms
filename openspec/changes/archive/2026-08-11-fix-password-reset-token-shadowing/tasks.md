## 1. Branch and reproducing spec

- [x] 1.1 Create a `fix/password-reset-token-shadowing` branch off `master`.
- [x] 1.2 Add a request spec (`spec/requests/security/password_reset_token_spec.rb`) reproducing the
      break: it captures the token the mailer actually emits, follows the link, and asserts it
      currently fails to resolve the account (red) and resolves after the fix.

## 2. Fix the reset lookup (Rails 6.1–8.1 — column-based, not the 7.1+ finder)

- [x] 2.1 In `email_helper.rb#send_password_reset_email`, emit `read_attribute(:password_reset_token)`
      (the DB column) so the emitted link carries the value the controller's column lookup matches —
      dodging the Rails 7.1+ shadowing method on every supported version. (The originally-planned
      generated-token finder is 7.1+ only; see design.md D1.)
- [x] 2.2 Keep the current-site-scoped column lookup in `sessions_controller.rb#forgot`
      (`current_site.users.where(password_reset_token: params[:h])`), which is the intrinsic site
      boundary; refuse a blank token.
- [x] 2.3 Make the `password_reset_sent_at` expiry window nil-safe (a nil timestamp is expired, not a
      `NoMethodError`); keep the 2-hour window (version-agnostic, no generated-token expiry).

## 3. Single-use and blank-password guards

- [x] 3.1 Clear the column token after a successful reset so the link cannot be replayed.
- [x] 3.2 Reject a blank-password submission so it does not report success with the password unchanged.

## 4. Docs

- [x] 4.1 CHANGELOG "Unreleased" entry: recovery restored; outstanding reset links invalidated.
- [x] 4.2 `docs/upgrading-to-2.9.3.md` already existed (installer change) — appended a short
      password-reset section and a rollout bullet rather than recreating it.

## 5. Verification

- [x] 5.1 Reproducing spec passes; coverage added for expiry, single-use replay, blank password, and
      the foreign-site scenario (the last under `users_share_sites: false`, the boundary's precondition).
- [x] 5.2 `bin/rubocop` clean on touched files.
- [x] 5.3 `bin/rspec` green (spec + the broader sessions suite).
- [x] 5.4 `bin/brakeman --no-pager` clean.
- [x] 5.5 `(cd spec/dummy && bin/rails zeitwerk:check)` passes.
- [x] 5.6 Archive this change on the branch before merge, as part of the PR.
