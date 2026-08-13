# password-strength-policy Specification

## Purpose
Ensure account passwords meet a minimum strength. Without a floor, a user (or an admin creating an
account) could set a trivially short, guessable password that the login throttle and hashing cannot
compensate for.
## Requirements
### Requirement: Passwords meet a minimum length

The default user model SHALL reject a password shorter than 8 characters whenever a password is set —
on account creation, password change, or reset. An update that does not set a password SHALL NOT be
forced to supply one. The existing maximum length SHALL continue to apply.

#### Scenario: A short password is rejected

- **WHEN** a password shorter than 8 characters is set on a user
- **THEN** the record is invalid with a password error

#### Scenario: A sufficiently long password is accepted

- **WHEN** a password of at least 8 characters is set on a user
- **THEN** the record is valid

#### Scenario: An unrelated update does not require a password

- **WHEN** an existing user is updated without changing the password
- **THEN** the update succeeds

