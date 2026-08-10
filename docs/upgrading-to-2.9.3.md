# Upgrading to 2.9.3

Version `2.9.3` hardens the installer and the auto-provisioned administrator account (audit finding
C1). It introduces one breaking change for automated installs and one action for operators of existing
installs.

## Installer setup token (BREAKING for scripted installs)

The first-run web installer now requires a **setup token** for **remote** requests, so it cannot be
completed by an anonymous visitor who reaches a freshly deployed app before the operator does.

- **Local installs are exempt** — a request from the local host (installing on `localhost`, or over an
  `ssh -L` tunnel) needs no token, because local access already proves host access.
- For a remote install, provide the token via `CAMALEON_SETUP_TOKEN` in the environment, or read the
  auto-generated value from `tmp/camaleon_setup_token` (also logged on first access) and enter it in the
  installer form.
- Automated or scripted **remote** installs that drive the installer must now supply
  `CAMALEON_SETUP_TOKEN`.
- The token is required only while no site exists; once installed, the installer is closed as before.
- The loopback exemption uses `request.local?`, which trusts your reverse proxy (if any) to forward the
  real client IP via `X-Forwarded-For` — standard configuration. A proxy that strips it would let a
  remote request appear local, so set `CAMALEON_SETUP_TOKEN` in that case as defense in depth.

See [docs/installation.md](installation.md) for the full flow.

## Default administrator no longer uses a known password

Previously a new site was provisioned with the administrator `admin` / `admin123`, and the installer's
confirmation page displayed those credentials to anyone who visited it.

### What changed

- New installs mint the `admin` account with a **randomly generated password**, shown **once** on the
  installer confirmation page (with a copy button) and never persisted where it can be read back.
- The confirmation page is now reachable only by the operator who just completed setup, not by anonymous
  visitors.
- A newly provisioned administrator is required to change its password on first sign-in.

### Recommended action for existing installs

Upgrading does **not** rewrite existing accounts. If your site was installed before this release and its
administrator still uses the default password, **rotate it now** — either from the admin profile screen,
or from a Rails console on the server:

```bash
rails console
```
```ruby
u = CamaleonCms::User.find_by(username: "admin")
u.update(password: "your-new-password", password_confirmation: "your-new-password")
```

The disclosure itself (the credentials showing on the installer's confirmation page) is closed for all
installs by this release, regardless of whether you rotate.

## Administrator password reset restored

On Rails 7.1+, `has_secure_password` generates a `password_reset_token` method that shadowed
Camaleon's same-named database column: the mailer emailed one value while the reset lookup matched
the other, so every emailed reset link dead-ended on "URL incorrect" even though the user was told
the email was sent. This release aligns both sides on the stored column (which behaves identically on
Rails 6.1–8.1), and makes reset links single-use, time-bounded, and confined to the account's own
site.

- **Any reset links already outstanding at upgrade time are invalidated** and must be re-requested —
  they were non-functional in practice anyway.
- No schema change; no action beyond re-requesting a reset if one was in flight.

## Recommended rollout

1. Upgrade to `2.9.3`.
2. For scripted installs, set `CAMALEON_SETUP_TOKEN` before running the installer.
3. On existing installs, rotate any administrator still using the historical default password.
4. Re-request any administrator password-reset link that was outstanding at upgrade time.
