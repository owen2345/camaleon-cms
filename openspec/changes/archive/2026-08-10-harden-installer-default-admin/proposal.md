## Why

A fresh Camaleon install auto-creates a superadmin (`role: 'admin'`) with the hardcoded password
`admin123`, and `GET /admin/installers/welcome` prints those credentials to anonymous visitors. That
page is the one action exempted from the installer's own `Site.count == 0` gate, so it stays
reachable **forever** on a fully installed site — an unauthenticated path to full administrative
control. Separately, on a brand-new deploy (`Site.count == 0`) the installer's `save` action is
itself unauthenticated, so whoever reaches the app first can provision it and own the resulting
superadmin.

The credentials-minting happens in a single place — `Site#default_settings`
(`site_default_settings.rb:113-117`) — which fires for **every** site creation, so the same known
password is minted on secondary sites created through the settings UI when `users_share_sites` is
`false`, not just through the installer.

## What Changes

- **The auto-provisioned administrator is never created with a known password.** `Site#default_settings`
  generates a random password and records a "must change password" marker on the account, replacing
  the hardcoded `admin123`. This covers every provisioning path, not only the installer.
- **The generated password is surfaced exactly once, only to the operator who provisioned the site.**
  The installer `welcome` page shows it and is reachable only via a one-time session marker set by
  `save`; it is no longer world-readable. Sites provisioned through the settings UI surface the
  password once to the authenticated administrator who created them.
- **The generated password carries a copy-to-clipboard control.** The operator copies it with one
  click rather than hand-selecting a random string, on both the welcome page and the settings surface.
- **A newly provisioned administrator must change its password before reaching the admin panel.**
  A gate redirects an account still carrying the must-change marker to the change-password screen,
  allowing only that screen and logout through. Applies to newly minted accounts; existing installs
  are not force-rotated (their credential leak is already closed by the `welcome` gating above).
- **The installer cannot be run by an unauthenticated party on a fresh deploy.** A setup token,
  readable only from the server's environment or filesystem, is required to run the installer and is
  consumed once setup completes. **BREAKING** for automated/scripted installs: the installer now
  requires a setup token.
- **Docs:** a new `docs/installation.md` (the updated install steps, now including the setup-token
  step and the first-login password change), a `docs/upgrading-to-2.9.3.md` migration guide following
  the `upgrading-to-2.9.2.md` template, and a CHANGELOG entry with upgrade notes — including an
  explicit instruction for operators of existing installs to rotate an admin still using the default
  password. This also gives the dangling "updated installation steps" link on camaleon.website
  (a relative-href typo pointing at the GitHub repo) a real, maintained target in the repo.

## Capabilities

### New Capabilities
- `installer-access-control`: who may run the site installer and view its output — the setup-token
  requirement gating the installer on a fresh deploy, and the restriction of the `welcome` page to
  the operator who just completed setup rather than to anonymous visitors.
- `default-admin-credential-safety`: the credential lifecycle of the auto-provisioned administrator —
  minted with a random password (never a known default) on every provisioning path, surfaced once to
  the provisioner (with a copy-to-clipboard control), and required to be changed before the account is
  used to access the admin panel.

### Modified Capabilities
<!-- None. No existing capability specifies installer access or the default admin's credentials;
     both areas are introduced fresh by this change. -->

## Impact

- **Controllers:** `admin/installers_controller.rb` (setup-token gate, one-time `welcome` marker,
  redirect target), `admin_controller.rb` (must-change gate), `admin/settings/sites_controller.rb`
  (surface the generated password to the creating admin), `admin/users_controller.rb` (the
  change-password path the gate must exempt).
- **Models:** `concerns/camaleon_cms/site_default_settings.rb` (random password + must-change marker;
  expose the generated plaintext transiently to the caller).
- **New:** boot-time setup-token provisioning (generated when `Site.count == 0`), read from
  `ENV['CAMALEON_SETUP_TOKEN']` or a generated file.
- **Views / locales:** `installers/form` (setup-token field), `installers/welcome` (show generated
  password + copy-to-clipboard control), new strings.
- **Docs:** new `docs/installation.md` and `docs/upgrading-to-2.9.3.md`; CHANGELOG entry.
- **Storage:** the must-change marker is stored in user meta — no migration (the engine ships a fixed
  schema and a data column would force downstream `schema.rb` regeneration).
- **Compatibility:** scripted installs must now supply a setup token; the `welcome` page no longer
  serves credentials to anonymous callers.
- **Tests:** feature specs that reproduce both C1 vectors (public `welcome` disclosure; unauthenticated
  `save`) and assert the hardened behavior, per the security-fix testing requirement in AGENTS.md.
