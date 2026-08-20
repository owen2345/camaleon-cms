# Make the email-confirmation token single-use (M16)

## Why

The password-reset path was hardened to clear its token on use (#1248), but
`SessionsController#confirm_email` marked the email valid and left `confirm_email_token` in place, so
the same confirmation link stayed live indefinitely. The practical impact is small — replaying it
only re-marks an already-valid email — but a one-time token should be consumed on use like the reset
token, closing the residual half of audit finding M16.

### Triage verdict: legit

`confirm_email` never cleared the token. Reproduced in
`spec/requests/security/confirm_email_token_spec.rb`: after a successful confirmation the token is
still present (and still resolves the account) before the fix, and is cleared after.

## What Changes

- On successful confirmation, `confirm_email` clears `confirm_email_token` and `confirm_email_sent_at`
  (`update_columns`, mirroring the reset-token single-use line), so the link cannot be replayed.

## Notes for upgraders

- None. Confirmation links are one-time by design; this enforces it.
