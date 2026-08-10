## Context

See proposal.md — Why. The relevant current-state facts that shape the approach:

- The auto-provisioned admin is minted in one place, `Site#default_settings`
  (`site_default_settings.rb:113-117`), fired by `Site` `after_create`. Both the installer
  (`InstallersController#save`) and `Admin::Settings::SitesController#create` reach it through
  `Site#save`, so a single change to that method covers every provisioning path.
- `InstallersController` (`installers_controller.rb`) skips authentication entirely and gates only on
  `Site.count == 0`, with `welcome` exempted from even that.
- `User` includes `CamaleonCms::Metas`, so a per-account flag can be stored without a schema change.
- `AdminController` runs a `before_action` chain (`cama_authenticate` first); a new gate slots in
  after authentication resolves `cama_current_user`.
- Password reset is currently non-functional (the `has_secure_password` `password_reset_token` method
  shadows the same-named DB column the controller queries) and is being fixed under a separate change,
  so this change does not depend on it. Fresh installs also frequently have no SMTP configured, so
  email recovery cannot be assumed as the fallback for a missed one-time password display — hence the
  file safeguard (D2).
- The installer UI today is a single three-field form (`installers/form.html.erb`: domain, name,
  theme) whose submit lands on `installers/welcome.html.erb`. That is the entire surface this change
  touches.

## Goals / Non-Goals

**Goals:**
- No provisioning path ever creates an administrator with a password an attacker could know.
- The generated password is recoverable by the legitimate operator (who has host access) but never
  disclosed to an anonymous caller — with a one-click copy control so it is usable in practice.
- Closing both C1 vectors — the public `welcome` disclosure and the unauthenticated installer.
- Shipping updated installation and 2.9.3 migration docs, and giving the camaleon.website "updated
  installation steps" link a maintained in-repo target.

**Non-Goals:**
- Retroactively rotating the password of admins on already-installed sites (force-change applies to
  newly minted accounts only; the disclosure is closed for existing installs by the `welcome` gate).
- Reworking the installer UI beyond its two touch-points: the setup-token field on the form and the
  welcome page's password display with its copy-to-clipboard control. No multi-step wizard, no in-form
  collection of admin credentials, no theme preview — the surface stays minimal.
- Fixing the broken password-reset flow — tracked as a separate change; this change only avoids
  depending on it (recovery leans on the file safeguard and a console reset instead).

## Decisions

### D1 — Setup token: `ENV` override, else a generated operator-readable file
On boot, when `Site.count == 0`, the app ensures a setup token exists: it uses
`ENV['CAMALEON_SETUP_TOKEN']` if set, otherwise generates a high-entropy token and writes it to an
operator-readable file under the app's writable state (default `tmp/camaleon_setup_token`), logging
its location once. The installer requires a matching token to provision, and the generated file is
removed once a site exists.
- *Why:* possession proves host access, which is exactly the line between the real operator and a web
  visitor — the same model Jenkins/GitLab use for their initial secret. The `ENV` override handles
  read-only or ephemeral filesystems (e.g. Heroku); the generated file handles the common case with
  zero pre-configuration.
- *Alternatives:* bind-the-installer-to-the-first-requester (rejected: racy, and the attacker may be
  first); store the token in the DB (rejected: awkward when `Site.count == 0` and no better than a
  file); require a rake/console step to install (rejected: heavier operator burden, larger UX change).

### D2 — Keep minting in `Site#default_settings`; surface the plaintext to the caller transiently
Provisioning stays in `default_settings` (single source of truth). It generates the password, assigns
it, and exposes the plaintext to the caller through a transient in-memory accessor on the `Site`
instance (not persisted, not logged). The installer reads it after `save` to stash for the one-time
welcome display; the settings controller reads it to surface once to the creating admin. The plaintext
is deliberately **never** written to a log or file — that would reintroduce the credential-disclosure
class this change exists to close (cf. audit finding M9), and the setup-token file is deleted on
install completion anyway. An operator who misses the one-time display recovers through a `rails
console` password reset (documented in the install guide), and through the email reset flow once the
sibling fix lands.
- *Why:* moving minting into the installer would either duplicate logic into the settings path or
  leave secondary-site provisioning (under `users_share_sites: false`) still minting a known password
  or no admin at all — both regressions. One method, surfaced per entry point, keeps it complete.
- *Alternative:* return the created user + plaintext up the call stack explicitly (rejected: the
  `after_create` callback boundary makes a transient accessor cleaner than threading a return value).

### D3 — Store the must-change marker in user meta, not a column
The "must change password" flag lives in user meta (`set_meta`/`get_meta`).
- *Why:* the engine ships a fixed schema; a new column would force downstream apps to regenerate
  `schema.rb`. Meta is the project's established place for per-record flags and needs no migration.
- *Trade-off:* a meta lookup per gated request rather than a column read — negligible, and cacheable.

### D4 — Force-change applies to newly minted accounts only
The marker is set at provisioning time. Existing installs are not detected or force-rotated.
- *Why:* the operator chose this scope. Retroactive detection would either bake the literal default
  password into a login-time check or require an operator-run remediation task; both were declined.
  The acute disclosure is already closed for existing installs by the `welcome` gate (D6), leaving
  only "an old install may still use a weak known password," which the CHANGELOG upgrade note
  addresses by instructing operators to rotate.

### D5 — The must-change gate is a `before_action` on `AdminController`, reusing the existing change path
A gate runs after `cama_authenticate`. If `cama_current_user` carries the marker, it redirects to the
existing password-change screen, exempting that screen, the password-change submit action, and
sign-out (and non-HTML/asset requests) to avoid a redirect loop. Completing the change clears the
marker.
- *Why:* reusing `users_controller`'s existing change-password path avoids a new screen and keeps the
  surface small.

### D6 — Welcome gating via a one-time session marker set at `save`
`save` records a one-time in-session indication on success and redirects to `welcome`; `welcome`
requires it, shows the credentials, and clears it. `save` also redirects to the admin login (not the
frontend root) so the operator lands where they sign in. The `Site.count == 0` gate is *not* extended
to `welcome` (that would make it unreachable immediately after install — the reason the original code
exempted it); the session marker is what replaces the missing gate.
- *Why:* `Site.count` answers "may anyone still install?" (a global fact); `welcome` needs "did *you*
  just install?" (a per-request fact). Only a per-session marker can answer the latter.

### D7 — Installation and migration docs in `docs/`, matching the 2.9.2 pattern
`docs/installation.md` carries the updated install steps (the README sequence plus the setup-token step
and the first-login password change). `docs/upgrading-to-2.9.3.md` follows the structure of
`docs/upgrading-to-2.9.2.md` (breaking-changes list, per-change sections, recommended rollout), and the
CHANGELOG "Unreleased" entry links both.
- *Why:* the project already versions upgrade guides under `docs/`; the installation doc gives the
  camaleon.website "updated installation steps" link a maintained in-repo target (its current href is a
  relative-path typo that 404s).
- *Note:* the docs are authored during apply, against the shipped behavior, so they cannot drift from
  what actually ships.

### D8 — Loopback requests are exempt from the setup token (on by default)
The token is required only for **remote** requests; a request from the local host (`request.local?`)
provisions without one. The setup-token field on the installer form is therefore client-side optional
(server-enforced for remote only).
- *Why:* the token exists to stop an anonymous *remote* visitor from installing on a public fresh
  deploy. Local access already proves host access — the same thing the token demonstrates — so a local
  operator installing on `localhost` or over an `ssh -L` tunnel gains nothing from typing it. Auto-*fetching*
  the token in the app was rejected as self-defeating: the app always holds the file, so validating it
  against itself authorizes everyone, including the remote attacker. A "who" must be attached, and
  loopback is that "who".
- *Trade-off:* `request.local?` uses the computed client IP, so a real remote client is gated **as long
  as** the reverse proxy forwards `X-Forwarded-For` (standard). A proxy that strips it would let a remote
  request appear local; operators in that situation set `CAMALEON_SETUP_TOKEN` as defense in depth. This
  is the same `XFF` trust Rails places everywhere, deemed acceptable for the default.

## Risks / Trade-offs

- **Operator misses the one-time welcome display and the password is random** → recovery is a
  documented `rails console` password reset (the operator already has host access — that is how they
  read the setup token), with the email reset path added once the sibling fix lands. The plaintext is
  never persisted (D2). Called out in the install guide and upgrade notes.
- **Setup token on a clustered / read-only deploy** → `ENV['CAMALEON_SETUP_TOKEN']` override (D1);
  boot-time file generation is idempotent (only when absent) so multiple workers converge.
- **Gate causes a redirect loop or locks the operator out of the change screen** → the change screen,
  its submit action, and logout are explicitly exempted; covered by a feature spec.
- **Scripted/automated installs break** (BREAKING) → documented; automation supplies
  `CAMALEON_SETUP_TOKEN`.

## Migration Plan

- **Deploy:** set `CAMALEON_SETUP_TOKEN` for scripted installs, or read the generated token from the
  logged file path for a manual first-run install.
- **Existing installs:** no automatic change; the upgrade note instructs operators whose admin still
  uses the historical default password to rotate it.
- **Rollback:** revert the change; the setup token and must-change marker are additive (meta + a file)
  and leave no schema residue.

## Resolved During Implementation

- The forced change reuses the existing profile-edit screen (`users#profile_edit`), whose
  "Change Password" modal already posts to `users#updated_ajax`. The gate exempts `profile`,
  `profile_edit`, `update`, and `updated_ajax`, so a marked admin has a working, non-dead-end path.
- Task 2.4 (persist the generated password as a lockout safeguard) was dropped: writing the plaintext
  to a log or file reintroduces the disclosure class this change closes, and the setup-token file is
  deleted on install completion. Recovery is a documented `rails console` reset (see D2).
- A latent bug surfaced and was fixed: `CamaleonRecord#cama_remove_cache` dereferenced `@cama_cache_vars`
  without the `||= {}` guard its siblings use, so `delete_meta` (used to clear the marker) crashed on a
  cold instance.
