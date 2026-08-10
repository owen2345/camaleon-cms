## Why

Administrator password reset is silently broken on current installs. On Rails 7.1+,
`has_secure_password` generates a `password_reset_token` **method** that shadows Camaleon's same-named
database column: the mailer emails the method's signed token, while `SessionsController#forgot` looks
the account up by the column (`where(password_reset_token: params[:h])`). The two never match, so every
emailed reset link dead-ends on "URL incorrect" while the user is told the email was sent. The engine
runs Rails 8.1, so this affects every current install. Separately, the reset token is never consumed,
so a link that *did* work would remain replayable for its whole window.

## What Changes

- **The mailer emits the token the lookup actually uses** — the DB column, read explicitly via
  `read_attribute` so it dodges the Rails 7.1+ shadowing method — so a legitimate reset link resolves
  to its account. (The engine supports Rails 6.1 → 8.1; the framework generated-token finder is 7.1+
  only, so the cross-version fix is column-based on both sides. See design.md D1.)
- **The lookup stays scoped to the current site** (`current_site.users`), so a token cannot be redeemed
  against an unrelated site.
- **Reset links become single-use and time-bounded**: the column token is cleared after a successful
  reset (so a used link cannot be replayed), and the 2-hour `password_reset_sent_at` window is kept but
  no longer crashes on a nil timestamp.
- **A blank password submitted through the reset form no longer reports success without changing
  anything.**
- The `password_reset_token` / `password_reset_sent_at` columns remain load-bearing (they are the
  cross-version mechanism); no schema change.
- **Docs:** a CHANGELOG entry noting that recovery is restored and that any reset links already
  outstanding at upgrade time are invalidated and must be re-requested.

## Capabilities

### New Capabilities
- `password-reset-token-validation`: emailed password-reset links resolve to the correct account,
  expire, and are single-use, so administrator account recovery is reliable and safe.

### Modified Capabilities
<!-- None. No existing capability specifies the password-reset flow; it is introduced fresh here. -->

## Impact

- **Controllers:** `admin/sessions_controller.rb#forgot` — refuse a blank token, keep the
  current-site-scoped column lookup, make the `password_reset_sent_at` window nil-safe, clear the token
  after a successful reset (single-use), and reject a blank-password reset.
- **Helpers/mailers:** `helpers/camaleon_cms/email_helper.rb` — emit `read_attribute(:password_reset_token)`
  (the column) so the link carries the value the lookup matches on Rails 7.1+.
- **Model:** `CamaleonCms::User` — no change; the column scheme is the cross-version mechanism.
- **Compatibility:** Rails 6.1 → 8.1. Reset links issued before the upgrade stop working and must be
  re-requested; the columns remain load-bearing.
- **Docs:** CHANGELOG entry (and, if the 2.9.3 migration guide exists at apply time, a short note there).
- **Tests:** a spec reproducing the broken lookup (an emailed link's token does not resolve today),
  plus expiry, single-use, and foreign-site coverage.
