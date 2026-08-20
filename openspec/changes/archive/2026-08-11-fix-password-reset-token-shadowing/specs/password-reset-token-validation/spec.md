## Purpose

Ensures the administrator password-reset link a user receives by email actually identifies their
account, expires after a bounded window, and cannot be replayed once used — so account recovery is
reliable and safe.

## ADDED Requirements

### Requirement: An emailed reset link resolves to its account

A password-reset link SHALL be validated against the same token value that was emailed to the user,
so that following a legitimate link presents that user's password-reset form. A reset request that
carries no token, or a token that does not correspond to any account, SHALL be refused without
resetting any password.

#### Scenario: A legitimate reset link is accepted
- **WHEN** a user follows the reset link delivered to their email within its validity window
- **THEN** the password-reset form is presented for that user's account

#### Scenario: An unrecognized token is refused
- **WHEN** a reset request supplies a token that matches no account
- **THEN** the request is refused and no password is changed

### Requirement: Reset links expire

A reset link SHALL stop being accepted after a bounded expiry window from when it was issued.

#### Scenario: An expired link is refused
- **WHEN** a user follows a reset link after its expiry window has passed
- **THEN** the request is refused and no password is changed

### Requirement: Reset links are single-use

Once a reset link has been used to successfully change a password, the same link SHALL NOT be usable
to change the password again.

#### Scenario: A used link cannot be replayed
- **WHEN** a reset link is used to change a password successfully, and the same link is then submitted again
- **THEN** the second attempt does not change the password

### Requirement: A blank password is not accepted as a successful reset

Submitting the reset form without a new password SHALL NOT report success or leave the existing
password in place under the guise of a completed reset.

#### Scenario: Blank password is rejected
- **WHEN** a user submits the reset form with an empty password
- **THEN** the reset is not reported as successful and the existing password is unchanged

### Requirement: Reset links are honored only for the account's own site

In a multi-site install, a reset link SHALL be honored only in the context of the site the account
belongs to, so a token cannot be redeemed against an unrelated site.

#### Scenario: A token is not honored on a foreign site
- **WHEN** a reset link for an account on one site is submitted in the context of a different site that does not own the account
- **THEN** the request is refused and no password is changed
