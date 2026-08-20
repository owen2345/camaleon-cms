## Why

The User model enforced no minimum password length. `has_secure_password` validates only presence (on
create) and the 72-byte bcrypt maximum, so a one-character password was accepted for a new account, a
password change, or a reset. Audit finding M15.

### Triage verdict: legit

Reproduced in `spec/models/password_strength_policy_spec.rb`: a 7-character password saves on master.
Fails without the fix (stash-verified).

## What Changes

- The default `CamaleonCms::User` model validates `password` length `minimum: 8` (length-only, aligned
  with NIST 800-63B favoring length over character-class rules; the 72-byte maximum still applies).
- `allow_blank: true` so the rule fires whenever a password is actually set (create, reset, change) but
  a profile update that submits no password stays a no-op, and `has_secure_password`'s presence check
  continues to own the empty-on-create case.

## Notes for upgraders

- New passwords, password changes, and resets must be at least 8 characters. Existing stored passwords
  are unaffected until next changed. A host application that supplies its own `user_model` sets its own
  policy (this validation lives on Camaleon's default user).

## Out of scope

- Character-class/complexity rules and breached-password checks (deliberately length-only).
- The 72-byte maximum (already enforced by `has_secure_password`).
