## Purpose

Governs the credential lifecycle of the administrator that Camaleon provisions automatically when a
site is created, so that such an account never exists with a password an attacker could know or
guess, and cannot be used to reach the admin panel until its password has been set by its operator.

## Requirements

### Requirement: Auto-provisioned administrators never receive a known password

Whenever site provisioning creates an administrator automatically, that account SHALL be assigned a
randomly generated, high-entropy password rather than a fixed or predictable default. This SHALL hold
for every provisioning path, including the first-run installer and the creation of additional sites
through the settings interface.

#### Scenario: The installer provisions an admin with a random password
- **WHEN** the first site is provisioned through the installer
- **THEN** the created administrator's password is a randomly generated value, not a shared default

#### Scenario: A settings-created site provisions an admin with a random password
- **WHEN** an authenticated administrator creates an additional site through the settings interface and that path provisions a new administrator
- **THEN** the created administrator's password is a randomly generated value, not a shared default

### Requirement: The generated password is surfaced exactly once, to its provisioner

Because the generated password is random, it SHALL be surfaced to the operator who provisioned the
site so they can sign in — and SHALL be surfaced at most once, only to that operator, never to an
unauthenticated third party.

#### Scenario: The installer operator receives the generated password once
- **WHEN** the installer completes and redirects the operator to the welcome page
- **THEN** the generated password is displayed to that operator a single time

#### Scenario: The settings creator receives the generated password once
- **WHEN** an authenticated administrator creates an additional site that provisions a new administrator
- **THEN** the generated password is surfaced once to that authenticated administrator

#### Scenario: The displayed password can be copied with one action
- **WHEN** the generated password is displayed to its provisioner
- **THEN** a copy-to-clipboard control is offered alongside it so the value need not be selected by hand

### Requirement: A newly provisioned administrator must change its password before using the admin panel

An administrator provisioned with a generated password SHALL be marked as requiring a password
change. While the marker is set, requests to the admin panel SHALL be redirected to the
change-password screen; only that screen and signing out SHALL remain reachable. Completing the
password change SHALL clear the marker and restore normal access. Accounts that predate this behavior
and carry no marker SHALL NOT be forced to change their password.

#### Scenario: A marked administrator is redirected to change its password
- **WHEN** an administrator carrying the must-change marker requests any admin-panel action other than the change-password screen or sign-out
- **THEN** the request is redirected to the change-password screen

#### Scenario: The change-password screen and sign-out remain reachable while marked
- **WHEN** a marked administrator requests the change-password screen or signs out
- **THEN** the request is allowed to proceed

#### Scenario: Changing the password restores access
- **WHEN** a marked administrator completes a password change
- **THEN** the marker is cleared
- **AND** subsequent admin-panel requests are no longer redirected

#### Scenario: Pre-existing administrators are not force-rotated
- **WHEN** an administrator account that carries no must-change marker signs in
- **THEN** it reaches the admin panel without being required to change its password
