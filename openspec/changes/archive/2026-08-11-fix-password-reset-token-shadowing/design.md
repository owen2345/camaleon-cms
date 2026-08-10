## Context

See proposal.md — Why. The mechanics that shape the fix:

- `CamaleonCms::User` uses `has_secure_password`. On **Rails 7.1+** that generates a
  `password_reset_token` instance method (source: `activemodel/secure_password.rb`) which shadows the
  model's same-named database column. Verified on Rails 8.1: `user.password_reset_token` returns a
  signed, 15-minute token while `user.read_attribute(:password_reset_token)` returns the column. On
  **Rails ≤ 7.0 the method does not exist**, so the same read returns the column and the flow works.
- `email_helper.rb` builds the reset URL from `user_to_send.password_reset_token` — i.e. the shadowing
  method's signed token on 7.1+.
- `sessions_controller.rb#forgot` (line 71) resolves the account with
  `current_site.users.where(password_reset_token: params[:h]).first` — a SQL query on the column
  (`where` is never shadowed). On 7.1+ the email token and the lookup key are two different values, so
  the lookup always misses.
- The action also checks `password_reset_sent_at < 2.hours.ago` (which raises when the column is nil),
  never clears the token after a successful reset (replayable), and `ActiveModel`'s `password=` is a
  no-op for `""` so a blank submission "succeeds" without changing anything.

**Version constraint (updated 2026-08-10): the engine supports Rails 6.1 → 8.1.** The framework
generated-token finder (`find_by_password_reset_token`, `generates_token_for`) exists only on 7.1+, so
it cannot be the fix. The fix must use the DB column explicitly on both sides — which behaves
identically on every supported version.

## Goals / Non-Goals

**Goals:**
- A legitimate emailed reset link resolves to its account and lets the user set a new password.
- Reset links are single-use, time-bounded, and confined to the account's own site.

**Non-Goals:**
- Dropping the legacy `password_reset_token` / `password_reset_sent_at` columns (a migration); they are
  left vestigial.
- Reworking the forgot/reset views or the email delivery mechanism beyond the token value.

## Decisions

### D1 — Align both sides on the DB column, read explicitly to dodge the shadow (Rails 6.1–8.1)
Emit and look up the **column** value on both sides. The controller's `where(password_reset_token:
params[:h])` already queries the column correctly (a `where` clause is never shadowed); the only wrong
side is the mailer, which reads the shadowing method. Change the mailer to read the column via
`read_attribute(:password_reset_token)`, so on 7.1+ it emits the stored column token (matching the
lookup) and on ≤ 7.0 it reads the same column as before — one behavior across all supported versions.
- *Why:* this is the only approach that works on Rails 6.1 → 8.1. The framework generated-token finder
  (`find_by_password_reset_token`) — the originally-planned fix — does not exist before 7.1, so it
  would break the older half of the support range.
- *Consequence:* expiry and single-use are not free (the generated token gave them); they are provided
  explicitly (D3, D4), which also works on every version.
- *Alternative (rejected):* the 7.1+ generated-token finder — cleaner and self-expiring, but 7.1+ only.

### D2 — Preserve site scoping
Keep the lookup scoped to `current_site.users`, so a token cannot be redeemed against a site that does
not own the account.
- *Why:* under `users_share_sites: false` a token must not be redeemable against a foreign site. The
  column lookup is already an association query on `current_site.users`, so the boundary is intrinsic.

### D3 — Reject blank-password resets
Guard the update so an empty password does not report success. `has_secure_password` only validates
password presence on create, so on the reset (update) path a blank `password=` is a silent no-op that
`update` reports as success. Treat "no new password provided" as a failure and re-render the form.

### D4 — Single-use and a nil-safe expiry window
- **Single-use:** after a successful reset, clear the column token (`password_reset_token` /
  `password_reset_sent_at`) so the same link cannot be replayed. The generated-token scheme gave this
  for free; the column scheme must clear it.
- **Expiry:** keep the existing 2-hour `password_reset_sent_at` window (version-agnostic), but treat a
  nil timestamp as expired instead of raising `NoMethodError` on `nil < 2.hours.ago`.

### D5 — Refuse a blank token
Only treat a **present** `params[:h]` as a reset-link submission, so an empty token is refused rather
than turned into a `where(password_reset_token: '')` probe.

## Risks / Trade-offs

- **Reset links outstanding at upgrade time stop working** → on 7.1+ they were already non-functional
  (the lookup never matched); the CHANGELOG tells users to re-request. No silent regression.
- **Expiry stays the 2-hour column window** rather than the generated token's 15 minutes → keeps the
  documented behavior and avoids a version-specific mechanism; the window is unchanged, only its
  nil-crash is fixed.
- **The legacy columns remain in use** (not vestigial as first proposed) → the column scheme is the
  cross-version mechanism, so the columns stay load-bearing; dropping them is out of scope.
- **Coordination with the concurrent 2.9.3 docs** → this change adds its own CHANGELOG bullet; if
  `docs/upgrading-to-2.9.3.md` already exists at apply time, append a short note rather than recreating
  it.

## Migration Plan

- **Deploy:** no schema change; users with a pending (non-working) reset link re-request one.
- **Rollback:** revert; the legacy columns are untouched, so there is no schema residue.
