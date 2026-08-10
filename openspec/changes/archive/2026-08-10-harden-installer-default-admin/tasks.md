## 1. Branch and reproducing specs

- [x] 1.1 Create a `security/harden-installer-default-admin` branch off `master`.
- [x] 1.2 Add a feature spec reproducing the public disclosure: `GET /admin/installers/welcome` on an installed site must NOT render the admin credentials (fails against current code).
- [x] 1.3 Add a feature spec reproducing the unauthenticated install: on a fresh deploy (`Site.count == 0`), the installer create action without a setup token must NOT provision a site (fails against current code).
- [x] 1.4 Add a spec asserting an auto-provisioned admin is never created with the historical default password, on both the installer and settings paths.

## 2. Default-admin credential minting

- [x] 2.1 In `site_default_settings.rb` (~113-117), replace the fixed `admin123` with a high-entropy generated password (`SecureRandom`) for the auto-created administrator.
- [x] 2.2 Set the "must change password" marker in the new admin's meta at creation time.
- [x] 2.3 Expose the generated plaintext transiently on the `Site` instance (in-memory accessor, not persisted) for the caller to read after `save`.
- [x] 2.4 Do NOT persist the generated password (log/file) — that reintroduces the disclosure class this change closes (design D2, revised). Recovery for a missed one-time display is a documented `rails console` reset, covered by the install guide (task 7.2).

## 3. Setup-token gate (vector 2)

- [x] 3.1 Add lazy setup-token provisioning: on first remote installer access while `Site.count == 0`, use `ENV['CAMALEON_SETUP_TOKEN']` if set, else generate and write `tmp/camaleon_setup_token` (0600) idempotently, logging its path once.
- [x] 3.2 Add a `before_action` to `InstallersController` requiring a matching setup token on `save` for remote requests while no site exists; refuse provisioning otherwise. Loopback requests (`request.local?`) are exempt — local access already proves host access (design D8).
- [x] 3.3 Consume the token: remove the generated file once a site exists so it cannot be replayed.
- [x] 3.4 Add the setup-token field to the installer form view (client-side optional; server-enforced for remote only).

## 4. Welcome-page gating, password display, copy control

- [x] 4.1 In `InstallersController#save`, set a one-time in-session marker on success and redirect to the admin login path (not the frontend root).
- [x] 4.2 Gate `welcome` on the one-time marker: render only when present, then clear it; redirect away otherwise. Remove the `except: :welcome` exemption's role as the only guard.
- [x] 4.3 Update `installers/welcome.html.erb` to display the generated password from the marker instead of the hardcoded `admin123`.
- [x] 4.4 Add a copy-to-clipboard control next to the displayed password (self-contained JS, no new dependency).

## 5. Force-change gate

- [x] 5.1 Add a `before_action` to `AdminController` that redirects a `cama_current_user` carrying the must-change marker to the change-password screen.
- [x] 5.2 Exempt the change-password screen, its submit action (`users#updated_ajax`), and sign-out from the gate to avoid a redirect loop.
- [x] 5.3 Clear the marker when the password change completes.
- [x] 5.4 Verify a pre-existing admin with no marker is unaffected (no forced change).

## 6. Settings-path surfacing

- [x] 6.1 In `Admin::Settings::SitesController#create`, surface the generated password once to the authenticated creating administrator (flash) when that path provisions a new admin.
- [x] 6.2 Render that surfaced password with the same copy-to-clipboard control.

## 7. Views, locales, docs

- [x] 7.1 Add locale strings for the setup-token field, the welcome password display and copy control, and the must-change screen messaging.
- [x] 7.2 Write `docs/installation.md`: the updated install steps (the README sequence) plus the setup-token step and the first-login password change; make it the target the camaleon.website "updated installation steps" link should point at.
- [x] 7.3 Write `docs/upgrading-to-2.9.3.md` following the `upgrading-to-2.9.2.md` structure: breaking-changes list (setup-token requirement for scripted installs), per-change sections, recommended rollout, and the explicit instruction to rotate an existing install's admin still using the default password.
- [x] 7.4 Add a CHANGELOG "Unreleased" entry (lead paragraph + upgrader notes) linking both docs.

## 8. Verification

- [x] 8.1 Confirm the section-1 reproducing specs now pass, and add any missing coverage for the must-change gate exemptions and the setup-token lifecycle.
- [x] 8.2 `bin/rubocop -A` on touched files (lint before specs).
- [x] 8.3 `bin/rspec` green (1237 non-feature + 8 new security examples pass; feature specs pass individually — the lone `site_settings_custom_fields:22` failure is a pre-existing Capybara flake that fails identically on master).
- [x] 8.4 `bin/brakeman --no-pager` clean.
- [x] 8.5 `(cd spec/dummy && bin/rails zeitwerk:check)` passes.
- [x] 8.6 Archive this change (`/opsx:archive`) on the branch before merge, as part of the PR.
